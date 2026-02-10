# lib/aia/directives/web_and_file_directives.rb

require 'faraday'
require 'clipboard'

module AIA
  class WebAndFileDirectives < Directive
    PUREMD_API_KEY = ENV.fetch('PUREMD_API_KEY', nil)
    SKILLS_DIR     = File.expand_path('~/.claude/skills')

    desc "Fetch and include content from a webpage"
    def webpage(args, _context_manager = nil)
      if PUREMD_API_KEY.nil?
        'ERROR: PUREMD_API_KEY is required in order to include a webpage'
      else
        url = args.shift.to_s.strip
        puremd_url = "https://pure.md/#{url}"

        response = Faraday.get(puremd_url) do |req|
          req.headers['x-puremd-api-token'] = PUREMD_API_KEY
        end

        if 200 == response.status
          response.body
        else
          "Error: Status was #{response.status}\n#{ap response}"
        end
      end
    end
    alias_method :website, :webpage
    alias_method :web,     :webpage

    desc "List available Claude Code skills"
    def skills(_args = [], _context_manager = nil)
      unless Dir.exist?(SKILLS_DIR)
        puts "No skills directory found at #{SKILLS_DIR}"
        return nil
      end

      entries = Dir.children(SKILLS_DIR)
                   .select { |e| Dir.exist?(File.join(SKILLS_DIR, e)) }
                   .sort

      if entries.empty?
        puts "No skills found in #{SKILLS_DIR}"
      else
        puts "\nAvailable Skills"
        puts "================"
        entries.each { |name| puts "  #{name}" }
        puts "\nTotal: #{entries.size} skills"
      end

      nil
    end

    desc "Include a Claude Code skill from ~/.claude/skills/"
    def skill(args = [], _context_manager = nil)
      skill_name = args.first&.strip
      if skill_name.nil? || skill_name.empty?
        STDERR.puts "Error: /skill requires a skill name"
        return nil
      end

      skill_dir = resolve_skill_dir(skill_name)
      unless skill_dir
        STDERR.puts "Error: No skill matching '#{skill_name}' found in #{SKILLS_DIR}"
        return nil
      end

      skill_path = File.join(skill_dir, 'SKILL.md')
      unless File.exist?(skill_path)
        STDERR.puts "Error: Skill directory '#{File.basename(skill_dir)}' has no SKILL.md"
        return nil
      end

      File.read(skill_path)
    end

    desc "Paste content from the system clipboard"
    def paste(_args = [], _context_manager = nil)
      content = Clipboard.paste
      content.to_s
    rescue StandardError => e
      "Error: Unable to paste from clipboard - #{e.message}"
    end
    alias_method :clipboard, :paste

    private

    def resolve_skill_dir(skill_name)
      return nil unless Dir.exist?(SKILLS_DIR)

      exact = File.join(SKILLS_DIR, skill_name)
      return safe_skill_path(exact)  if Dir.exist?(exact)

      Dir.children(SKILLS_DIR)
         .sort
         .each do |entry|
        next unless entry.start_with?(skill_name)
        candidate = File.join(SKILLS_DIR, entry)
        return safe_skill_path(candidate) if Dir.exist?(candidate)
      end

      nil
    end

    def safe_skill_path(path)
      resolved = File.realpath(path)
      resolved.start_with?(File.realpath(SKILLS_DIR)) ? resolved : nil
    rescue Errno::ENOENT
      nil
    end
  end
end
