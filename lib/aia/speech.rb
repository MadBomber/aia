# frozen_string_literal: true

# lib/aia/speech.rb
#
# Shared text-to-speech behavior. Interactive handlers (ChatLoop,
# MentionRouter) include it: ContentExtractor duck-calls #speak on any
# includer that responds to it, and #speak only talks when --speak is on.
# The /say directive calls Speech.speak_text directly.

require 'shellwords'

module AIA
  module Speech
    # Players tried in order when audio.player is not set.
    PLAYERS = [
      %w[afplay],
      %w[mpv --no-video --really-quiet],
      %w[ffplay -nodisp -autoexit -loglevel quiet],
      %w[mpg123 -q]
    ].freeze

    module_function

    # Speak +text+ with the configured speak command (audio.speak_command,
    # default macOS `say`), whether or not --speak is on.
    #
    # @param text [String]
    # :reek:TooManyStatements -- two-stage TTS pipeline (convert, then play) with spinner and tempfile cleanup
    def speak_text(text)
      audio   = AIA.config.audio
      command = audio.speak_command || 'say'
      env     = {}
      env['SPEECH_MODEL'] = audio.speech_model if audio.speech_model

      if command == 'say'
        # Local TTS: say converts and plays in one step
        run_with_spinner("Speaking...") { system(env, *say_command(audio.voice, text)) }
      else
        speak_with_script(env, command, text)
      end
    rescue StandardError => e
      $stderr.puts "Warning: Speech failed: #{e.message}"
    end

    # The macOS `say` argument list, with -v VOICE when a voice is set.
    def say_command(voice, text)
      voice.nil? || voice.to_s.strip.empty? ? ['say', text] : ['say', '-v', voice, text]
    end

    # Custom TTS script: convert text to an audio file (AIA passes the
    # output path as $2), then play the file.
    def speak_with_script(env, command, text)
      require 'tempfile'
      tmpfile = Tempfile.new(['aia-tts-', '.mp3'])
      tmpfile.close
      path = tmpfile.path
      run_with_spinner("Converting to audio...") { system(env, command, text, path) }
      play(path) if File.size?(path)
    ensure
      tmpfile&.unlink
    end

    # Play an audio file with audio.player, or the first known player found.
    def play(path)
      player = player_command(AIA.config.audio.player)
      unless player
        $stderr.puts "Warning: No audio player found. Set audio.player (for example `mpv`)."
        return
      end

      run_with_spinner("Speaking...") { system(*player, path) }
    end

    # The player command as an argument list: the configured one (split like
    # a shell would), or the first of PLAYERS on the PATH.
    def player_command(configured)
      return Shellwords.split(configured.to_s) unless configured.to_s.strip.empty?

      PLAYERS.find { on_path?(it.first) }
    end

    def on_path?(program)
      ENV['PATH'].to_s.split(File::PATH_SEPARATOR).any? { File.executable?(File.join(it, program)) }
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

    # Speak a response when --speak is on.
    def speak(content)
      return unless AIA.speak?

      Speech.speak_text(content.to_s)
    end
  end
end
