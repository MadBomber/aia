# frozen_string_literal: true

# lib/aia/speech.rb
#
# Shared text-to-speech behavior for interactive handlers (ChatLoop,
# MentionRouter). ContentExtractor duck-calls #speak on any includer
# that responds to it, so both sides route through this one pipeline.

module AIA
  module Speech
    private

    # :reek:TooManyStatements -- two-stage TTS pipeline (convert, then play) with spinner and tempfile cleanup
    def speak(content)
      return unless AIA.speak?

      audio   = AIA.config.audio
      command = audio.speak_command || 'say'
      voice   = audio.voice
      text    = content.to_s
      env     = {}
      env['SPEECH_MODEL'] = audio.speech_model if audio.speech_model

      if command == 'say'
        # Local TTS: say converts and plays in one step
        run_with_spinner("Speaking...") do
          if voice && !voice.to_s.strip.empty?
            system(env, command, '-v', voice, text)
          else
            system(env, command, text)
          end
        end
      else
        # Custom TTS script: stage 2 = convert text → audio file,
        # stage 3 = play the file. AIA passes the output path as $2.
        require 'tempfile'
        tmpfile = Tempfile.new(['aia-tts-', '.mp3'])
        tmpfile.close
        path = tmpfile.path
        begin
          run_with_spinner("Converting to audio...") do
            system(env, command, text, path)
          end
          if File.size?(path)
            run_with_spinner("Speaking...") do
              system('afplay', path)
            end
          end
        ensure
          tmpfile.unlink
        end
      end
    rescue StandardError => e
      $stderr.puts "Warning: Speech failed: #{e.message}"
    end

    def run_with_spinner(message)
      spinner = TTY::Spinner.new("[:spinner] #{message}", format: :bouncing_ball, output: $stderr)
      spinner.auto_spin
      begin
        yield
      ensure
        spinner.stop
      end
    end
  end
end
