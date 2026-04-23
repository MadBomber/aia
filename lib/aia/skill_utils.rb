# lib/aia/skill_utils.rb

require 'yaml'

module AIA
  module SkillUtils
    extend self

    def path_based_id?(id)
      id.to_s.start_with?('/', './', '../', '~/')
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

    def find_skill_dir(skill_name, base_dir)
      if path_based_id?(skill_name)
        expanded = File.expand_path(skill_name)
        return expanded if Dir.exist?(expanded)
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

    def safe_skill_path(path, dir)
      resolved = File.realpath(path)
      resolved.start_with?(File.realpath(dir)) ? resolved : nil
    rescue Errno::ENOENT
      nil
    end
  end
end
