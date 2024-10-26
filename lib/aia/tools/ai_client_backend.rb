# lib/aia/tools/ai_client_backend.rb

# This is WIP in the `develop` branch
# do not use.

require 'ai_client'
require_relative 'backend_common'

class AIA::AiClientBackend < AIA::Tools
  include AIA::BackendCommon

  meta(
    name:     'ai_client',
    role:     :backend,
    desc:     'AI Client integration for unified model access',
    url:      'https://github.com/path/to/ai_client', # TODO: Update URL
    install:  'gem install ai_client',
  )

  attr_reader :client, :raw_response
  
  DEFAULT_PARAMETERS = ''
  DIRECTIVES = %w[
    model
    temperature
    max_tokens
    top_p
    frequency_penalty
    presence_penalty
  ]

  def initialize(text: "", files: [])
    super
    @client = AiClient.new
  end

  def build_command
    # No-op - ai_client doesn't use command line
    @parameters = ""
  end

  def run
    handle_model(AIA.config.model)
  rescue => e
    puts "Error handling model #{AIA.config.model}: #{e.message}"
  end

  private

  def handle_model(model_name)
    case model_name
    when /vision/
      image2text
    when /^gpt/
      text2text
    when /^dall-e/
      text2image
    when /^tts/
      text2audio
    when /^whisper/
      audio2text
    else
      raise "Unsupported model: #{model_name}"
    end
  end

  def text2text
    response = client.complete(
      prompt: text,
      model: AIA.config.model,
      temperature: AIA.config.temp
    )
    response.completion
  end

  # Placeholder methods to maintain API compatibility
  def image2text
    raise "Not yet implemented for ai_client"
  end

  def text2image
    raise "Not yet implemented for ai_client"
  end

  def text2audio
    raise "Not yet implemented for ai_client"
  end

  def audio2text
    raise "Not yet implemented for ai_client"
  end
end
