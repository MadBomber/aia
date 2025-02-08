# lib/aia/client_manager.rb

class AIA::ClientManager
  def initialize_client(type: :chat, model: nil)
    @client = case type
    when :code
      AIA::Client.code
    when :image
      AIA::Client.image
    when :speech
      AIA::Client.speech
    when :audio
      AIA::Client.audio
    else
      AIA::Client.chat
    end
  end
end

#
# Manages the initialization and lifecycle of AI clients used by the system
#
# This class handles the creation and configuration of different types of AI clients
# (chat, code, image, speech) based on the current configuration settings. It ensures
# the appropriate model is used for each type of interaction.
#
# @example
#   manager = ClientManager.new(config)
#   manager.initialize_client(:chat)
#   manager.initialize_client(:code)
#
