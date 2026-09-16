# examples/plugins/quick_file_tool.rb
#
# Simple LLM-usable helper for quick file inspection.
# Provides a top-level method that can be called from prompts/ERB/plugins:
#
#   <%= quick_file_tool('README.md') %>
#   <%= quick_file_tool('lib/aia/plugin_loader.rb', lines: '1-40') %>
#
# This is intentionally read-only.

def quick_file_tool(path, lines: nil)
  full_path = File.expand_path(path.to_s, Dir.pwd)

  return "Error: path is required" if path.to_s.strip.empty?
  return "Error: file not found: #{path}" unless File.file?(full_path)

  content = File.read(full_path)
  return content if lines.nil? || lines.to_s.strip.empty?

  match = lines.to_s.match(/\A(\d+)-(\d+)\z/)
  return "Error: lines must be in START-END format" unless match

  start_line = match[1].to_i
  end_line = match[2].to_i
  return "Error: invalid line range" if start_line <= 0 || end_line < start_line

  selected = content.lines[(start_line - 1)..(end_line - 1)] || []
  return "Error: requested lines are out of range" if selected.empty?

  selected.each_with_index.map do |line, idx|
    "#{start_line + idx}: #{line}"
  end.join
end
