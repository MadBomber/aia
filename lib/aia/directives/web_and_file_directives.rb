# lib/aia/directives/web_and_file_directives.rb

require 'faraday'
require 'clipboard'

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

      entries = Dir.children(dir)
                   .select { |e|
                     File.directory?(File.join(dir, e)) &&
                     File.exist?(File.join(dir, e, 'SKILL.md'))
                   }
                   .select { |e|
                     next true if positive_terms.empty? && negative_terms.empty?
                     text = read_front_matter_text(File.join(dir, e, 'SKILL.md'))
                     positive_terms.all? { |t| text.include?(t) } &&
                       negative_terms.none? { |t| text.include?(t) }
                   }
                   .sort

      if entries.empty?
        all_terms = positive_terms + negative_terms
        puts all_terms.empty? ? "No skills found in #{dir}" : "No skills matched: #{Array(args).join(' ')}"
        return nil
      end

      wrap_width = terminal_width - 2

      entries.each do |skill_id|
        fm = parse_skill_front_matter(File.join(dir, skill_id, 'SKILL.md'))
        name        = fm['name']        || ''
        description = fm['description'] || '(no description)'
        puts "#{skill_id}: #{name}"
        puts word_wrap(description, width: wrap_width, indent: '  ')
        puts
      end

      nil
    end

    desc "Include an AIA skill from the configured skills directory"
    def skill(args = [], _context_manager = nil)
      args = Array(args)
      skill_name = args.first&.strip
      if skill_name.nil? || skill_name.empty?
        msg = "Error: /skill requires a skill name. Use /skills to list available skills."
        AIA::LoggerManager.aia_logger.error(msg)
        puts msg
        return nil
      end

      dir = aia_skills_dir
      skill_dir = find_skill_dir(skill_name, dir)
      unless skill_dir
        msg = "Error: No skill matching '#{skill_name}' found in #{dir}. Use /skills to list available skills."
        AIA::LoggerManager.aia_logger.error(msg)
        puts msg
        return nil
      end

      return File.read(skill_dir) if File.file?(skill_dir)

      skill_path = File.join(skill_dir, 'SKILL.md')
      unless File.exist?(skill_path)
        msg = if path_based_id?(skill_name)
                "Error: No skill matching '#{skill_name}' found in #{dir}. Use /skills to list available skills."
              else
                "Error: Skill '#{File.basename(skill_dir)}' has no SKILL.md in #{dir}."
              end
        AIA::LoggerManager.aia_logger.error(msg)
        puts msg
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

    # Resolve the AIA skills directory from config, env vars, or defaults.
    def aia_skills_dir
      if AIA.respond_to?(:config) && AIA.config&.skills&.respond_to?(:dir) && AIA.config.skills.dir
        return AIA.config.skills.dir
      end

      prompts_dir   = ENV.fetch('AIA_PROMPTS__DIR', File.expand_path('~/.prompts'))
      skills_prefix = ENV.fetch('AIA_PROMPTS__SKILLS_PREFIX', 'skills')
      File.join(prompts_dir, skills_prefix)
    end

    def terminal_width
      require 'io/console'
      IO.console&.winsize&.last || 80
    rescue StandardError
      80
    end

    # Word-wrap text to width, prefixing every line with indent.
    def word_wrap(text, width:, indent: '')
      return "#{indent}#{text}" if text.length <= width

      words = text.split(' ')
      lines = []
      line  = +''

      words.each do |word|
        if line.empty?
          line = word
        elsif line.length + 1 + word.length <= width
          line << ' ' << word
        else
          lines << line
          line = word
        end
      end
      lines << line unless line.empty?

      lines.map { |l| "#{indent}#{l}" }.join("\n")
    end

    def read_front_matter_text(skill_md_path)
      content = File.read(skill_md_path)
      return '' unless content.start_with?("---")

      end_pos = content.index("---", 3)
      return '' unless end_pos

      content[3...end_pos].downcase
    end

    def parse_skill_front_matter(skill_md_path)
      require 'yaml'
      content = File.read(skill_md_path)
      return {} unless content.start_with?("---")

      end_pos = content.index("---", 3)
      return {} unless end_pos

      yaml_text = content[3...end_pos].strip
      parsed    = YAML.safe_load(yaml_text, symbolize_names: false) rescue {}
      parsed.is_a?(Hash) ? parsed : {}
    end
  end
end
