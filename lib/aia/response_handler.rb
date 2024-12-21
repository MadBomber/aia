# lib/aia/response_handler.rb



class AIA::ResponseHandler
  def initialize(result:, logger:)
    @result = result
    @logger = logger
  end

  def process
    speak_result if AIA.config.speak?
    log_result
    start_chat if AIA.config.chat?
  end
end

