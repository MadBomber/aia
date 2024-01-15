# aia/lib/aia/tools/backend_common.rb

# Used by both the AIA::Mods and AIA::Sgpt classes

module AIA::BackendCommon
  attr_accessor :command, :text, :files, :parameters

  def initialize(text: "", files: [])
    @text       = text
    @files      = files
    @parameters = self.class::DEFAULT_PARAMETERS.dup
    build_command
  end


  def sanitize(input)
    Shellwords.escape(input)
  end


  def build_command
    @parameters += " --model #{AIA.config.model} " if AIA.config.model
    @parameters += AIA.config.extra

    set_parameter_from_directives

    @command = "#{meta.name} #{@parameters} "
    @command += sanitize(text)

    puts @command if AIA.config.debug?

    @command
  end


  def set_parameter_from_directives
    AIA.config.directives.each do |entry|
      directive, value = entry
      if self.class::DIRECTIVES.include?(directive)
        @parameters += " --#{directive} #{sanitize(value)}" unless @parameters.include?(directive)
      end
    end
  end


  def run
    case @files.size
    when 0
      @result = `#{build_command}`
    when 1
      @result = `#{build_command} < #{@files.first}`
    else
      @result = %x[cat #{@files.join(' ')} | #{build_command}]
    end

    @result
  end
end
