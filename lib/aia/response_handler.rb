# lib/aia/response_handler.rb



class AIA::ResponseHandler
  def initialize(result:, prompt: nil)
    @result = result
    @prompt = prompt
  end

  def process
    speak_result if AIA.config.speak?
    log_result
    start_chat if AIA.config.chat?
  end

  private

  def log_result
    AIA::Logging.new(AIA.config.log_file).info "Prompt: #{@prompt}\nResult: #{@result}"
  end
end

#
# Handles the processing and output of AI responses
#
# This class manages what happens with AI responses after they are received,
# including:
# - Text-to-speech conversion if enabled
# - Logging of interactions
# - Initiating chat mode if requested
# - Managing the response output format
#
# The handler ensures consistent processing of AI responses across different
# interaction modes (single prompt, chat, pipeline).
#
