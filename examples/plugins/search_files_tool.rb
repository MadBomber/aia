# frozen_string_literal: true

# examples/examples/plugins/search_files_tool.rb
#
# RubyLLM tool plugin for recursive code/text search using The Silver Searcher.
#
# Example prompting:
#   "Use the search_files tool to find where PluginLoader is defined."
#   "Use search_files to look for TODO comments under lib."
#
# Notes:
# - Uses `ag` recursively from a provided directory.
# - Uses `--noheading --nocolor --numbers` so output is stable and parseable.
# - Returns matching file paths, line numbers, and lines.
# - Read-only.

require 'open3'
require 'shellwords'
require 'ruby_llm/tool'

class SearchFilesTool < RubyLLM::Tool
  def self.name = 'search_files'

  description <<~DESC
    Recursively search a directory using the `ag` (The Silver Searcher) CLI.
    Use this to find where symbols, strings, TODOs, config keys, or error messages
    appear in a project. Returns matching file paths, line numbers, and lines.
  DESC

  parameter :pattern, type: :string, required: true,
            description: 'Search pattern to pass to ag. Usually a plain string, but regex syntax is also supported by ag.'
  parameter :directory, type: :string,
            description: 'Directory to search recursively. Defaults to the current working directory.'
  parameter :file_type, type: :string,
            description: 'Optional ag file type filter, such as ruby, js, md, yaml, or shell.'
  parameter :max_results, type: :integer,
            description: 'Maximum number of matching lines to return. Defaults to 50.'

  def available?
    system('command -v ag >/dev/null 2>&1')
  end

  def execute(pattern:, directory: '.', file_type: nil, max_results: 50)
    return { success: false, error: 'pattern is required' } if pattern.to_s.strip.empty?

    dir = File.expand_path(directory.to_s.strip.empty? ? '.' : directory.to_s, Dir.pwd)
    return { success: false, error: "directory not found: #{directory}" } unless Dir.exist?(dir)

    limit = normalize_limit(max_results)

    cmd = ['ag', '--noheading', '--nocolor', '--numbers']
    cmd += ag_file_type_args(file_type)
    cmd += [pattern.to_s, dir]

    stdout, stderr, status = Open3.capture3(*cmd)

    if status.success?
      lines = stdout.lines.map(&:chomp).reject(&:empty?)
      trimmed = lines.first(limit)
      {
        success: true,
        tool: self.class.name,
        pattern: pattern,
        directory: dir,
        file_type: file_type,
        total_matches_returned: trimmed.size,
        truncated: lines.size > limit,
        matches: trimmed
      }
    elsif status.exitstatus == 1
      {
        success: true,
        tool: self.class.name,
        pattern: pattern,
        directory: dir,
        file_type: file_type,
        total_matches_returned: 0,
        truncated: false,
        matches: []
      }
    else
      {
        success: false,
        error: stderr.to_s.strip.empty? ? 'ag command failed' : stderr.to_s.strip,
        command: cmd.shelljoin
      }
    end
  rescue StandardError => e
    {
      success: false,
      error: e.message
    }
  end

  private

  def ag_file_type_args(file_type)
    type = file_type.to_s.strip.downcase
    return [] if type.empty?

    case type
    when 'ruby' then ['--ruby']
    when 'js', 'javascript' then ['--js']
    when 'ts', 'typescript' then ['--ts']
    when 'md', 'markdown' then ['--markdown']
    when 'yaml', 'yml' then ['--yaml']
    when 'shell', 'sh', 'bash' then ['--shell']
    else ["--#{type}"]
    end
  end

  def normalize_limit(value)
    limit = value.to_i
    return 50 if limit <= 0

    [limit, 500].min
  end
end
