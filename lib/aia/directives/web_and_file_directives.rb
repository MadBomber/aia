# lib/aia/directives/web_and_file_directives.rb

require 'faraday'
require 'clipboard'
require 'yaml'
require 'io/console'

module AIA
  class WebAndFileDirectives < Directive
    PUREMD_API_KEY = ENV.fetch('PUREMD_API_KEY', nil)

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

    desc "List available AIA skills"
    def skills(args = [], _context_manager = nil)
      dir = aia_skills_dir

      unless Dir.exist?(dir)
        puts "No skills directory found at #{dir}"
        return nil
      end

      positive_terms, negative_terms = parse_search_terms(Array(args))

      skill_dirs = Dir.children(dir)
                      .select { |e| Dir.exist?(File.join(dir, e)) }
                      .sort

      if skill_dirs.empty?
        puts "No skills found in #{dir}"
        return nil
      end

      matching = skill_dirs.select do |name|
        fm_text = read_front_matter_text(File.join(dir, name, 'SKILL.md'))
        text = "#{name} #{fm_text}"
        pos_ok = positive_terms.empty? || positive_terms.all? { |t| text.include?(t) }
        neg_ok = negative_terms.none? { |t| text.include?(t) }
        pos_ok && neg_ok
      end

      if matching.empty?
        puts "No skills matching your query"
        return nil
      end

      width = terminal_width
      puts "\nAvailable Skills (#{dir}):"
      puts "=" * [width, 60].min

      matching.each do |name|
        skill_path = File.join(dir, name, 'SKILL.md')
        fm = parse_skill_front_matter(skill_path)
        display_name = fm['name'] || name
        desc_text = fm['description'].to_s.strip
        puts "\n  #{display_name}"
        puts word_wrap(desc_text, width: width - 4, indent: '    ') unless desc_text.empty?
      end

      puts "\nTotal: #{matching.size} skill#{'s' if matching.size != 1}"

      nil
    end

    desc "Include an AIA skill from the skills directory"
    def skill(args = [], _context_manager = nil)
      args = Array(args)
      skill_name = args.first&.strip

      if skill_name.nil? || skill_name.empty?
        warn "Error: /skill requires a skill name. Use /skills to list available skills."
        AIA::LoggerManager.aia_logger.error("/skill requires a skill name")
        return nil
      end

      dir = aia_skills_dir

      unless Dir.exist?(dir)
        warn "Error: Skills directory not found at #{dir}"
        AIA::LoggerManager.aia_logger.error("Skills directory not found at #{dir}")
        return nil
      end

      skill_dir = resolve_skill_dir(skill_name, dir)
      unless skill_dir
        warn "Error: No skill matching '#{skill_name}' found in #{dir}. Use /skills to list available skills."
        AIA::LoggerManager.aia_logger.error("No skill matching '#{skill_name}' found in #{dir}")
        return nil
      end

      skill_path = File.join(skill_dir, 'SKILL.md')
      unless File.exist?(skill_path)
        warn "Error: Skill directory '#{File.basename(skill_dir)}' has no SKILL.md. Use /skills to list available skills."
        AIA::LoggerManager.aia_logger.error("Skill directory '#{File.basename(skill_dir)}' has no SKILL.md")
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

    def aia_skills_dir
      AIA.config.skills.dir
    end

    def resolve_skill_dir(skill_name, dir)
      exact = File.join(dir, skill_name)
      return safe_skill_path(exact, dir) if Dir.exist?(exact)

      Dir.children(dir).sort.each do |entry|
        next unless entry.start_with?(skill_name)
        candidate = File.join(dir, entry)
        return safe_skill_path(candidate, dir) if Dir.exist?(candidate)
      end

      nil
    end

    def safe_skill_path(path, dir)
      resolved = File.realpath(path)
      resolved.start_with?(File.realpath(dir)) ? resolved : nil
    rescue Errno::ENOENT
      nil
    end

    def terminal_width
      IO.console&.winsize&.last || 80
    rescue StandardError
      80
    end

    def word_wrap(text, width:, indent:)
      words = text.split
      lines = []
      current = indent.dup

      words.each do |word|
        if current.length + word.length + (current == indent ? 0 : 1) > width
          lines << current
          current = indent + word
        else
          current += current == indent ? word : " #{word}"
        end
      end
      lines << current unless current == indent
      lines.join("\n")
    end

    def read_front_matter_text(path)
      return '' unless File.exist?(path)
      parse_skill_front_matter(path).values.join(' ').downcase
    end

    def parse_skill_front_matter(path)
      return {} unless File.exist?(path)
      content = File.read(path)
      return {} unless content.start_with?('---')
      end_marker = content.index("\n---", 3)
      return {} unless end_marker
      yaml_text = content[3...end_marker]
      YAML.safe_load(yaml_text) || {}
    rescue StandardError
      {}
    end
  end
end
