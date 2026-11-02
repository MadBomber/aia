# frozen_string_literal: true

# examples/examples/plugins/list_ruby_methods_tool.rb
#
# RubyLLM tool plugin for listing Ruby method definitions in a directory tree.
# This avoids shell-output quirks by parsing Ruby source lines directly.

require 'find'
require 'ruby_llm/tool'

class ListRubyMethodsTool < RubyLLM::Tool
  def self.name = 'list_ruby_methods'

  description <<~DESC
    Recursively scan Ruby source files in a directory and list method definitions.
    Useful for codebase inventory, navigation, and understanding available APIs.
    Returns methods grouped by file, including line numbers and whether each
    method is an instance method or a class method.
  DESC

  parameter :directory, type: :string,
            description: 'Directory to scan recursively. Defaults to the current working directory.'
  parameter :max_files, type: :integer,
            description: 'Maximum number of Ruby files to scan. Defaults to 500.'
  parameter :max_methods, type: :integer,
            description: 'Maximum number of methods to return. Defaults to 2000.'

  METHOD_REGEX = /^\s*def\s+(self\.)?([A-Za-z_][A-Za-z0-9_]*[!?=]?)/

  def execute(directory: '.', max_files: 500, max_methods: 2000)
    dir = File.expand_path(directory.to_s.strip.empty? ? '.' : directory.to_s, Dir.pwd)
    return { success: false, error: "directory not found: #{directory}" } unless Dir.exist?(dir)

    file_limit = normalize_limit(max_files, default: 500, hard_max: 5000)
    method_limit = normalize_limit(max_methods, default: 2000, hard_max: 20_000)

    ruby_files = candidate_files(dir).first(file_limit)

    results = {}
    total_methods = 0

    ruby_files.each do |path|
      methods = extract_methods(path)
      next if methods.empty?

      remaining = method_limit - total_methods
      break if remaining <= 0

      methods = methods.first(remaining)
      rel = relative_path(path, dir)
      results[rel] = methods
      total_methods += methods.size
    end

    {
      success: true,
      tool: self.class.name,
      directory: dir,
      scanned_files: ruby_files.size,
      files_with_methods: results.size,
      total_methods: total_methods,
      truncated: total_methods >= method_limit,
      methods_by_file: results
    }
  rescue StandardError => e
    {
      success: false,
      error: e.message
    }
  end

  private

  def candidate_files(dir)
    files = []

    Find.find(dir) do |path|
      next unless File.file?(path)
      next unless ruby_file?(path)

      files << path
    end

    files.sort
  end

  def ruby_file?(path)
    basename = File.basename(path)
    ext = File.extname(path)
    ext == '.rb' || basename == 'Rakefile'
  end

  def extract_methods(path)
    methods = []

    File.foreach(path).with_index(1) do |line, line_no|
      match = line.match(METHOD_REGEX)
      next unless match

      methods << {
        name: match[2],
        kind: match[1] ? 'class' : 'instance',
        line: line_no,
        source: line.rstrip
      }
    end

    methods
  end

  def relative_path(path, base_dir)
    return path unless path.start_with?(base_dir + File::SEPARATOR)

    path.delete_prefix(base_dir + File::SEPARATOR)
  end

  def normalize_limit(value, default:, hard_max:)
    limit = value.to_i
    return default if limit <= 0

    [limit, hard_max].min
  end
end
