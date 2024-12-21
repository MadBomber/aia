# lib/aia/prompt_processor.rb


class AIA::PromptProcessor
  def initialize(directives:, config:, prompt:)
    @directives = directives
    @config = config
    @prompt = prompt
  end

  def process
    prompt = build_prompt
    get_and_display_result(prompt)
  end
end


