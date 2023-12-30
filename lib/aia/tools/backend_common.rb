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

    @command = "#{self.class::meta.name} #{@parameters} "
    @command += sanitize(text)

    puts @command if AIA.config.debug?

    @command
  end

  def set_parameter_from_directives
    AIA.config.directives.each do |directive, value|
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
      create_temp_file_with_contexts
      run_with_temp_file
      clean_up_temp_file
    end

    @result
  end

  def create_temp_file_with_contexts
    @temp_file = Tempfile.new("#{self.class::COMMAND_NAME}-context")

    @files.each do |file|
      content = File.read(file)
      @temp_file.write(content)
      @temp_file.write("\n")
    end

    @temp_file.close
  end

  def run_with_temp_file
    command = "#{build_command} < #{@temp_file.path}"
    @result = `#{command}`
  end

  def clean_up_temp_file
    @temp_file.unlink if @temp_file
  end
end
