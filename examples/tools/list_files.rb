
# experiments/ai_misc/coding_agent_with_ruby_llm/tools/list_files.rb
#
require "ruby_llm/tool"

module Tools
  class ListFiles < RubyLLM::Tool
    def self.name = "list_files"

    description "List files and directories at a given path. If no path is provided, lists files in the current directory."
    param :path, desc: "Optional relative path to list files from. Defaults to current directory if not provided."

    def execute(path: Dir.pwd)
      Dir.glob(File.join(path, "*"))
         .map { |filename| File.directory?(filename) ? "#{filename}/" : filename }
    rescue => e
      { error: e.message }
    end
  end
end
