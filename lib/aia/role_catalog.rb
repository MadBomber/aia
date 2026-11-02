# frozen_string_literal: true

# lib/aia/role_catalog.rb
#
# Finding, checking and listing role files. Every function takes the prompts
# directory and roles prefix explicitly, so callers pass the configured
# values (--prompts-dir, the config file, AIA_PROMPTS__DIR) rather than
# guessing them.

require_relative 'skill_utils'
require_relative 'errors'

module AIA
  module RoleCatalog
    module_function

    # A role ID with the roles prefix added ("editor" -> "roles/editor").
    # Path-based IDs and IDs that already carry the prefix are unchanged.
    def qualified_id(role_id, prefix)
      id = role_id.to_s
      return id if SkillUtils.path_based_id?(id) || prefix.to_s.empty? || id.start_with?("#{prefix}/")

      "#{prefix}/#{id}"
    end

    # The file a role ID names.
    def role_file(role_id, dir:, prefix:, extname: '.md')
      SkillUtils.prompt_file_path(qualified_id(role_id, prefix), dir: dir, extname: extname)
    end

    # Role IDs (without the prefix) under <dir>/<prefix>. Files and folders
    # starting with "_" are private and not listed.
    def names(dir, prefix, extname: '.md')
      roles_dir = File.join(dir.to_s, prefix.to_s)
      return [] unless Dir.exist?(roles_dir)

      Dir.glob("**/*#{extname}", base: roles_dir)
         .map { it.delete_suffix(extname) }
         .reject { |f| f.split('/').any? { it.start_with?('_') } }
         .sort
    end

    # Raise AIA::ConfigurationError unless the role's file exists.
    def validate!(role_id, dir:, prefix:, extname: '.md')
      file = role_file(role_id, dir: dir, prefix: prefix, extname: extname)
      return if File.exist?(file)

      message = if SkillUtils.path_based_id?(role_id)
                  "Role file not found: #{file}"
                else
                  not_found_message(file, dir, prefix, extname)
                end
      raise AIA::ConfigurationError, message
    end

    def not_found_message(file, dir, prefix, extname = '.md')
      available = names(dir, prefix, extname: extname)
      message = "Role file not found: #{file}\n\n"

      if available.empty?
        message + "No roles directory found at #{File.join(dir.to_s, prefix.to_s)}\n" \
                  "Create the directory and add role files to use this feature."
      else
        message + "Available roles:\n" + available.map { "  - #{it}" }.join("\n") +
          "\n\nCreate the role file or use an existing role."
      end
    end

    # The --list-roles report: a heading and front-matter table per role.
    def listing(dir, prefix, extname: '.md')
      roles_dir = File.join(dir.to_s, prefix.to_s)
      unless Dir.exist?(roles_dir)
        return "No roles directory found at #{roles_dir}\nCreate this directory and add role files to use roles."
      end

      roles = names(dir, prefix, extname: extname)
      return "No role files found in #{roles_dir}\nCreate #{extname} files in this directory to define roles." if roles.empty?

      roles.flat_map { listing_entry(roles_dir, it, extname) }.join("\n")
    end

    def listing_entry(roles_dir, role_id, extname)
      front_matter = SkillUtils.parse_front_matter(File.join(roles_dir, "#{role_id}#{extname}"))
      rows = front_matter.map { |key, value| "| #{key} | #{value.to_s.gsub('|', '\\|')} |" }
      ["## #{role_id}", '', '| Key | Value |', '|-----|-------|', *rows, '']
    end
  end
end
