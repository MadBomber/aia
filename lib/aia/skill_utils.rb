# lib/aia/skill_utils.rb

require 'yaml'
require_relative 'errors'

module AIA
  module SkillUtils
    extend self

    def path_based_id?(id)
      id.to_s.start_with?('/', './', '../', '~/')
    end

    # Parse a comma-separated skills string into a list of plain skill ids.
    # "security, ruby-style" => ["security", "ruby-style"]. Skill ids named by
    # a tool must be plain ids looked up within the skills directory, so any id
    # that reads as a filesystem path is refused with an AIA::CrewError.
    def split_skills(skills)
      ids = skills.to_s.split(',').map(&:strip).reject(&:empty?)
      paths = ids.select { |id| path_based_id?(id) }
      return ids if paths.empty?

      raise AIA::CrewError, "skills must be names within the skills directory, not file paths: #{paths.join(', ')}"
    end

    # The file a prompt ID names. A path-based ID ("./x", "~/p/x.md") is
    # expanded, gaining +extname+ when it has none; any other ID is
    # relative to +dir+.
    def prompt_file_path(prompt_id, dir:, extname:)
      id = prompt_id.to_s
      return File.join(dir, "#{id}#{extname}") unless path_based_id?(id)

      expanded = File.expand_path(id)
      File.extname(expanded).empty? ? "#{expanded}#{extname}" : expanded
    end

    def parse_front_matter(path)
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

    # File extensions a skill given as a file path may have.
    SKILL_EXTENSIONS = %w[.md .markdown].freeze

    # Whether +path+ names a file that can't be a skill (not markdown).
    def non_markdown_skill_file?(path)
      File.file?(path) && !SKILL_EXTENSIONS.include?(File.extname(path).downcase)
    end

    # The warning for a skill path that names a non-markdown file.
    def non_markdown_skill_message(skill_id)
      "Skill '#{skill_id}' is not a markdown file (#{SKILL_EXTENSIONS.join(' or ')})"
    end

    # A skill directory or markdown file. Path IDs may name either; a file
    # must be markdown. Named skills are looked up in +base_dir+ only.
    def find_skill_dir(skill_name, base_dir)
      if path_based_id?(skill_name)
        expanded = File.expand_path(skill_name)
        return expanded if Dir.exist?(expanded)
        return expanded if File.file?(expanded) && !non_markdown_skill_file?(expanded)
        return nil
      end

      exact = File.join(base_dir, skill_name)
      return safe_skill_path(exact, base_dir) if Dir.exist?(exact)

      Dir.children(base_dir).sort.each do |entry|
        next unless entry.start_with?(skill_name)
        candidate = File.join(base_dir, entry)
        return safe_skill_path(candidate, base_dir) if Dir.exist?(candidate)
      end

      nil
    rescue Errno::ENOENT
      nil
    end

    def skill_body(content)
      return content unless content.start_with?('---')
      end_marker = content.index("\n---", 3)
      return content unless end_marker
      content[(end_marker + 4)..].lstrip
    end

    # Resolve the effective skills base directory from config.
    # Skills live in config.skills.dir (set via --skills-dir, the -c config file,
    # or the ~/.prompts/skills default). This is the single resolver used by both
    # skill loading and `--list-skills`, so what is listed is always loadable.
    #
    # @param config [AIA::Config] the AIA configuration
    # @return [String, nil] resolved base directory, or nil if not configured
    def skills_base_dir(config)
      config.skills&.dir
    end

    # Render the available skills as a markdown report — the body of --list-skills.
    # Resolves the directory via skills_base_dir (same as loading) and respects a
    # -c config file because it runs after config is built.
    #
    # @param config [AIA::Config]
    # @return [String] markdown listing, or a "no skills" message
    def list_skills_markdown(config)
      dir = skills_base_dir(config)

      unless dir && Dir.exist?(dir)
        return "No skills directory found at #{dir}\n" \
               "Create this directory and add skill subdirectories to use skills."
      end

      skill_ids = Dir.glob("*/SKILL.md", base: dir).map { |f| File.dirname(f) }.sort
      if skill_ids.empty?
        return "No skills found in #{dir}\n" \
               "Create subdirectories with a SKILL.md file to define skills."
      end

      skill_ids.flat_map { |id| skill_markdown_entry(dir, id) }.join("\n")
    end

    # Markdown lines for a single skill entry (heading + front-matter table).
    # Escapes pipe characters so values can't break the table.
    #
    # @return [Array<String>]
    def skill_markdown_entry(dir, skill_id)
      front_matter = parse_front_matter(File.join(dir, skill_id, 'SKILL.md'))
      lines = ["## #{skill_id}", ""]

      if front_matter.empty?
        lines << "_No front matter found in SKILL.md_"
      else
        lines << "| Key | Value |" << "|-----|-------|"
        front_matter.each do |key, value|
          lines << "| #{key} | #{value.to_s.gsub('|', '\\|')} |"
        end
      end

      lines << ""
      lines
    end

    # Load and concatenate content from multiple skills.
    # Used by both pipeline mode (prompt text injection) and chat mode
    # (system prompt injection) to honour the --skill CLI option.
    #
    # @param skill_ids [Array<String>] skill names or path-based IDs
    # @param skills_base_dir [String] base directory for named skills
    # @return [String, nil] joined skill bodies, or nil if none loaded
    def load_skills_content(skill_ids, skills_base_dir)
      ids = Array(skill_ids).reject { |s| s.nil? || s.strip.empty? }
      return nil if ids.empty?

      contents = ids.filter_map { |id| load_single_skill_content(id, skills_base_dir) }
      contents.empty? ? nil : contents.join("\n\n")
    end

    # Load the body of a single skill (front matter stripped).
    # Handles both name-based (looks in skills_base_dir) and path-based IDs.
    #
    # @param skill_id [String] skill name or path
    # @param skills_base_dir [String] base directory for named skills
    # @return [String, nil] skill body text, or nil on error
    def load_single_skill_content(skill_id, skills_base_dir)
      problem = skill_load_problem(skill_id, skills_base_dir)
      return skill_warning(problem) if problem

      skill_dir = find_skill_dir(skill_id, skills_base_dir)
      return skill_warning("Skill '#{skill_id}' not found in #{skills_base_dir}") unless skill_dir

      raw = read_skill_source(skill_dir)
      raw && skill_body(raw)
    rescue StandardError => e
      skill_warning("Could not load skill '#{skill_id}': #{e.message}")
    end

    # Why +skill_id+ can't be loaded before looking for it, or nil.
    def skill_load_problem(skill_id, skills_base_dir)
      path_id = path_based_id?(skill_id)
      unless path_id || (skills_base_dir && Dir.exist?(skills_base_dir))
        return "Skill '#{skill_id}' not loaded: skills directory #{skills_base_dir.inspect} does not exist"
      end
      return "#{non_markdown_skill_message(skill_id)}; not loaded" if path_id && non_markdown_skill_file?(File.expand_path(skill_id))

      nil
    end

    # The raw text of a found skill: the file itself, or the folder's SKILL.md.
    def read_skill_source(skill_dir)
      return File.read(skill_dir) if File.file?(skill_dir)

      skill_path = File.join(skill_dir, 'SKILL.md')
      return File.read(skill_path) if File.exist?(skill_path)

      skill_warning("SKILL.md not found in #{skill_dir}")
    end

    # Print a skill warning; returns nil so callers can `return skill_warning(...)`.
    def skill_warning(message)
      $stderr.puts "Warning: #{message}"
      nil
    end

    def safe_skill_path(path, dir)
      resolved = File.realpath(path)
      root = File.realpath(dir)
      root_with_separator = File.join(root, '')

      resolved == root || resolved.start_with?(root_with_separator) ? resolved : nil
    rescue Errno::ENOENT
      nil
    end
  end
end
