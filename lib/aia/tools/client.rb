# lib/aia/tools/client.rb

require_relative 'backend_common'

OpenAI.configure do |config|
  config.access_token = ENV.fetch("OPENAI_ACCESS_TOKEN")
end

class AIA::Client < AIA::Tools
  include AIA::BackendCommon

  meta(
    name:     'client',
    role:     :backend,
    desc:     'Ruby implementation of the OpenAI API',
    url:      'https://github.com/alexrudall/ruby-openai',
    install:  'gem install ruby-openai',
  )

  attr_reader :client, :raw_response
  
  DEFAULT_PARAMETERS  = ''
  DIRECTIVES          = []

  def initialize(text: "", files: [])
    super

    @client     = OpenAI::Client.new
  end

  def build_command
    # No-Op
  end


  def run
    handle_model(AIA.config.model)
  rescue => e
    puts "Error handling model #{AIA.config.model}: #{e.message}"
  end

  def speak(what = @text)
    print "Speaking ... " if AIA.verbose?
    text2audio(what)
    puts "Done."          if AIA.verbose?
  end


  ###########################################################
  private

  # Handling different models more abstractly
  def handle_model(model_name)
    case model_name
    when /vision/
      image2text

    when /^gpt.*$/, /^babbage.*$/, /^davinci.*$/
      text2text

    when /^dall-e.*$/
      text2image

    when /^tts.*$/
      text2audio

    when /^whisper.*$/
      audio2text

    else
      raise "Unsupported model: #{model_name}"
    end
  end


  def image2text
    # TODO: Implement
  end


  def text2text
    @raw_response = client.chat(
      parameters: {
          model:        AIA.config.model, # Required.
          messages:     [{ role: "user", content: text}], # Required.
          temperature:  AIA.config.temp,
      }
    )

    response = raw_response.dig('choices', 0, 'message', 'content')

    response
  end

  
  def text2image
    parameters = {
      model:    AIA.config.model,
      prompt:   text
    }

    parameters[:size]     = AIA.config.image_size     unless AIA.config.image_size.empty?
    parameters[:quality]  = AIA.config.image_quality  unless AIA.config.image_quality.empty?

    raw_response  = client.images.generate(parameters:)

    response = raw_response.dig("data", 0, "url")

    response
  end


  def text2audio(what = @text, save: false, play: true)
    raise "OpenAI's text to speech capability is not available" unless client

    player = select_audio_player

    response = client.audio.speech(
      parameters: {
        model: AIA.config.speech_model,
        input: what,
        voice: AIA.config.voice
      }
    )

    handle_audio_response(response, player, save, play)
  end


  def audio2text(path_to_audio_file = @files.first)
    response = client.audio.transcribe(
      parameters: {
        model: AIA.config.model,
        file: File.open(path_to_audio_file, "rb")
      }
    )

    response["text"]
  rescue => e
    "An error occurred: #{e.message}"
  end


  # Helper methods
  def select_audio_player
    case OS.host_os
    when /mac|darwin/
      'afplay'
    when /linux/
      'mpg123'
    when /mswin|mingw|cygwin/
      'cmdmp3'
    else
      raise "No MP3 player available"
    end
  end


  def handle_audio_response(response, player, save, play)
    Tempfile.create(['speech', '.mp3']) do |f|
      f.binmode
      f.write(response)
      f.close
      `cp #{f.path} #{Pathname.pwd + "speech.mp3"}` if save
      `#{player} #{f.path}` if play
    end
  end


  ###########################################################
  public

  class << self

    def list_models
      new.client.model.list      
    end


    def speak(what)
      save_model = AIA.config.model
      AIA.config.model = AIA.config.speech_model

      new(text: what).speak

      AIA.config.model = save_model
    end

  end

end


__END__


##########################################################
