# lib/aia/prompt_processor.rb


class AIA::PromptProcessor
  def initialize(directives:, prompt:)
    @directives = directives
    @prompt = prompt
    @config = AIA.config
  end

  def process
    prompt = build_prompt
    result = AIA::Client.chat.chat(prompt)
    display_result(result)
    result
  end

  private

  def display_result(a_string)
    puts "from display_result >>>"
    puts a_string
    puts "<<< display_result"
  end

  def build_prompt
    prompt = @prompt.to_s
    prompt.prepend("#{@directives}\n") unless @directives&.empty?
    prompt.prepend("Be terse in your response. ") if AIA.config.terse?
    prompt
  end
end

#
# Processes and prepares prompts before sending to AI models
#
# This class handles the preparation of prompts including:
# - Incorporating system directives
# - Applying terse mode modifications
# - Building the final prompt structure
#
# It acts as an intermediary between raw prompt text and the AI client,
# ensuring all prompts are properly formatted and enhanced before processing.
#
