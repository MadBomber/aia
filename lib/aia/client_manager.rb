# lib/aia/client_manager.rb

class AIA::ClientManager
  def initialize_client(type: :chat, model: nil)
    @client = case type
    when :code
      CodeClient.new(model || AIA.config.code_model)
    when :image
      ImageClient.new(model || AIA.config.image_model)
    when :speech
      SpeechClient.new(model || AIA.config.speech_model)
    else
      ChatClient.new(model || AIA.config.model)
    end
  end
end

