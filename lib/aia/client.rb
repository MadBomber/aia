# lib/aia/client.rb

require "ai_client"

module AIA
  class Client
    class << self
      def audio
        AiClient.new(AIA.config.audio_model || 'whisper-1')
      end

      def chat
        AiClient.new(AIA.config.model || 'gpt-4o')
      end

      def code
        AiClient.new(AIA.config.code_model)
      end

      def image
        AiClient.new(AIA.config.image_model || 'dall-e-3')
      end

      def tts
        AiClient.new(AIA.config.speech_model || 'tts-1')
      end
    end
  end
end
