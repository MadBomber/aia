# lib/aia/prompt_processor.rb


class AIA::PromptProcessor
  def initialize(directives:, prompt:)
    @directives = directives
    @prompt = prompt
    @config = AIA.config
  end

  def process
    prompt = build_prompt
    get_and_display_result(prompt)
  end

  private

  def build_prompt
    prompt = @prompt.to_s
    prompt.prepend("#{@directives}\n") unless @directives&.empty?
    prompt.prepend("Be terse in your response. ") if AIA.config.terse?
    prompt
  end
end

