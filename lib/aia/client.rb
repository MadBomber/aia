# lib/aia/client.rb

require "ai_client"

module AIA
  class Client
    class << self
      def audio = AiClient.new(AIA.config.audio_model)
      def chat  = AiClient.new(AIA.config.model)
      def code  = AiClient.new(AIA.config.code_model)
      def image = AiClient.new(AIA.config.image_model)
      def tts   = AiClient.new(AIA.config.speech_model)
    end
  end
end
