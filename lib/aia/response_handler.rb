# lib/aia/response_handler.rb



class AIA::ResponseHandler
  def initialize(result:)
    @result = result
  end

  def process
    speak_result if AIA.config.speak?
    log_result
    start_chat if AIA.config.chat?
  end

  private

  def log_result
    AIA.config.logger.prompt_result(@prompt, @result)
  end
end

