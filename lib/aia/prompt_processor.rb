# lib/aia/prompt_processor.rb


class AIA::PromptProcessor
  def process
    prompt = build_prompt
    get_and_display_result(prompt)
  end
end

