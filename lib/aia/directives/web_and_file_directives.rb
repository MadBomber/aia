# lib/aia/directives/web_and_file_directives.rb

require 'faraday'
require 'clipboard'
require 'yaml'
require 'io/console'
require 'word_wrapper'

module AIA
  class WebAndFileDirectives < Directive
    include AIA::SkillUtils
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

      skill_data = skill_dirs.filter_map do |name|
        fm = parse_front_matter(File.join(dir, name, 'SKILL.md'))
        text = "#{name} #{fm.values.join(' ').downcase}"
        pos_ok = positive_terms.empty? || positive_terms.all? { |t| text.include?(t) }
        neg_ok = negative_terms.none? { |t| text.include?(t) }
        [name, fm] if pos_ok && neg_ok
      end

      if skill_data.empty?
        puts "No skills matching your query"
        return nil
      end

      width = terminal_width
      puts "\nAvailable Skills (#{dir}):"
      puts "=" * [width, 60].min

      skill_data.each do |name, fm|
        display_name = fm['name'] || name
        desc_text = fm['description'].to_s.strip
        puts "\n  #{display_name}"
        unless desc_text.empty?
          puts WordWrapper::MinimumRaggedness.new(width - 4, desc_text).wrap
            .split("\n").map { |l| "    #{l}" }.join("\n")
        end
      end

      puts "\nTotal: #{skill_data.size} skill#{'s' if skill_data.size != 1}"
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

      skill_dir = find_skill_dir(skill_name, dir)
      unless skill_dir
        if path_based_id?(skill_name)
          warn "Error: No skill directory found at '#{File.expand_path(skill_name)}'. Use /skills to list available skills."
          AIA::LoggerManager.aia_logger.error("No skill directory found at '#{File.expand_path(skill_name)}'")
        else
          warn "Error: No skill matching '#{skill_name}' found in #{dir}. Use /skills to list available skills."
          AIA::LoggerManager.aia_logger.error("No skill matching '#{skill_name}' found in #{dir}")
        end
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

    def terminal_width
      IO.console&.winsize&.last || 80
    rescue StandardError
      80
    end

  end
end
