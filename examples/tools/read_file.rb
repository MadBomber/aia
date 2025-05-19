# experiments/ai_misc/coding_agent_with_ruby_llm/tools/read_file.rb
#
"ruby_llm/tool"

module Tools
  class ReadFile < RubyLLM::Tool
    description "Read the contents of a given relative file path. Use this when you want to see what's inside a file. Do not use this with directory names."
    param :path, desc: "The relative path of a file in the working directory."

    def execute(path:)
      File.read(path)
    rescue => e
      { error: e.message }
    end
  end
end
