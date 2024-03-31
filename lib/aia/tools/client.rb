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

  attr_reader :client
  
  DEFAULT_PARAMETERS  = ''
  DIRECTIVES          = []

  def initialize(text: "", files: [])
    super

    @client     = OpenAI::Client.new
  end

  def build_command; end


  # TODO: need to figure out a way to switch between
  #       the generic text-based prompt and the two
  #       specialized methods speak and transcript.
  #
  def run
    transcribe    
  end


  def speak(what)
    if client.nil?
      puts "\nWARNING: OpenAI's text to speech capability is not available at this time."
      return
    end

    player = if OS.osx?
                'afplay'
              elsif OS.linux?
                'mpg123'
              elsif OS.windows?
                'cmdmp3'
              else
                puts "\nWARNING: There is no MP3 player available"
                return
              end

    response = client.audio.speech(
      parameters: {
        model: AIA.config.speech_model,
        input: what,
        voice: AIA.config.voice
      }
    )

    Tempfile.create(['speech', '.mp3']) do |f|
      f.binmode
      f.write(response)
      f.close
      `#{player} #{f.path}`
    end
  end


  def transcribe(path_to_audio_file=@files.first)
    begin
      response = client.audio.transcribe(
        parameters: {
          model:  AIA.config.model, # "whisper-1 || whisper-2",
          file:   File.open(path_to_audio_file, "rb")
        }
      )
      
      response["text"]
    rescue => e
      "An error occurred: #{e.message}"
    end
  end

end

__END__


##########################################################
