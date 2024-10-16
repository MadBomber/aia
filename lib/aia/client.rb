# lib/aia/client.rb

require "ai_client"

# FIXME:  This does not allow for the model names
#         to change during a pipeline or chat
#
TTS   = AiClient.new(AIA.config.speech_model)
AI    = AiClient.new(AIA.config.model)
IMAGE = AiClient.new(AIA.config.image_model)
AUDIO = AiClient.new(AIA.config.audio_model)

# class AIA::Client
#   attr_accessor :command, :text, :files, :parameters


#   def initialize(model = AIA.config.model, **options)
#     AiClient.new(model, **options)
#   end


#   # TODO: Replace the old interface with something
#   #       that more closely fits fits with the common
#   #       usage for ai_client.


#   def old_initialize(text: "", files: [])
#     @text       = text
#     @files      = files
#     @parameters = self.class::DEFAULT_PARAMETERS.dup
#     build_command
#   end

#   # OBE
#   # def sanitize(input)
#   #   Shellwords.escape(input)
#   # end


#   # TODO: delete this. There is no longer a backend CLI processor
#   #
#   # def build_command
#   #   @parameters += " --model #{AIA.config.model} " if AIA.config.model
#   #   @parameters += AIA.config.extra
#   #
#   #   set_parameter_from_directives
#   #
#   #   @command = "#{meta.name} #{@parameters} "
#   #   @command += sanitize(text)
#   #
#   #   puts @command if AIA.config.debug?
#   #
#   #   @command
#   # end


#   # TODO: delete this. There is no longer a backend CLI processor
#   #
#   # def set_parameter_from_directives
#   #   AIA.config.directives.each do |entry|
#   #     directive, value = entry
#   #     if self.class::DIRECTIVES.include?(directive)
#   #       @parameters += " --#{directive} #{sanitize(value)}" unless @parameters.include?(directive)
#   #     end
#   #   end
#   # end


#   # TODO: delete this. There is no longer a backend CLI processor
#   #
#   # def run    
#   #   case @files.size
#   #   when 0
#   #     @result = `#{build_command}`
#   #   when 1
#   #     @result = `#{build_command} < #{@files.first}`
#   #   else
#   #     @result = %x[cat #{@files.join(' ')} | #{build_command}]
#   #   end

#   #   @result
#   # end
# end
