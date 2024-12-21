# lib/aia/response_handler.rb

class AIA::ResponseHandler
  def initialize(result:, config:, logger:)
    @result = result
    @config = config
    @logger = logger
  end

  def process
    speak_result if @config.speak?
    log_result
    start_chat if @config.chat?
  end
end
