# frozen_string_literal: true

require 'ruby_llm/tool'

class SearchReplaceTool < RubyLLM::Tool
  def self.name = 'search_replace'

  description <<~DESC
    Perform controlled search-and-replace on a single file.
    Supports exact-text replacement by default, with optional regex mode,
    replace-first vs replace-all behavior, and dry-run preview.
  DESC

  parameter :path, type: :string, required: true,
            description: 'Path to the file to modify.'
  parameter :search, type: :string, required: true,
            description: 'Exact text or regex pattern to search for.'
  parameter :replace, type: :string, required: true,
            description: 'Replacement text.'
  parameter :regex, type: :boolean,
            description: 'Treat search as a Ruby regular expression pattern.'
  parameter :replace_all, type: :boolean,
            description: 'Replace all occurrences. Defaults to true.'
  parameter :dry_run, type: :boolean,
            description: 'Preview the replacement without modifying the file.'

  def execute(path:, search:, replace:, regex: false, replace_all: true, dry_run: false)
    return error('path is required') if path.to_s.strip.empty?
    return error('search is required') if search.to_s.empty?

    full_path = File.expand_path(path.to_s, Dir.pwd)
    return error("file not found: #{path}") unless File.file?(full_path)

    original = File.read(full_path)
    updated, count = if regex
                       replace_regex(original, search.to_s, replace.to_s, replace_all)
                     else
                       replace_exact(original, search.to_s, replace.to_s, replace_all)
                     end

    if count.zero?
      return {
        success: true,
        path: full_path,
        changed: false,
        replacements: 0,
        dry_run: dry_run,
        message: 'No matches found'
      }
    end

    File.write(full_path, updated) unless dry_run

    {
      success: true,
      path: full_path,
      changed: true,
      replacements: count,
      dry_run: dry_run,
      before_preview: preview(original, search.to_s),
      after_preview: preview(updated, replace.to_s)
    }
  rescue RegexpError => e
    error("invalid regex: #{e.message}")
  rescue StandardError => e
    error(e.message)
  end

  private

  def error(message)
    {
      success: false,
      error: message
    }
  end

  def replace_exact(text, search, replace, replace_all)
    if replace_all
      count = text.scan(search).length
      [text.gsub(search, replace), count]
    else
      count = text.include?(search) ? 1 : 0
      [text.sub(search, replace), count]
    end
  end

  def replace_regex(text, pattern, replace, replace_all)
    rx = Regexp.new(pattern)
    if replace_all
      count = text.scan(rx).length
      [text.gsub(rx, replace), count]
    else
      count = text.match?(rx) ? 1 : 0
      [text.sub(rx, replace), count]
    end
  end

  def preview(text, needle)
    return text[0, 500] if needle.to_s.empty?

    idx = text.index(needle)
    return text[0, 500] unless idx

    start = [idx - 120, 0].max
    text[start, 500]
  end
end
