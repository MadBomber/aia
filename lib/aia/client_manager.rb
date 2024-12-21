# lib/aia/client_manager.rb

class AIA::ClientManager
  def initialize(config)
    @config = config
  end

  def initialize_client(type: :chat, model: nil)
    @client = case type
    when :code
      CodeClient.new(model || @config.code_model)
    when :image
      ImageClient.new(model || @config.image_model)
    when :speech
      SpeechClient.new(model || @config.speech_model)
    else
      ChatClient.new(model || @config.model)
    end
  end
end

