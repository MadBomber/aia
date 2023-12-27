# aia/lib/aia/tools/mods2.rb

require 'tempfile'

class AIA::Mods2 < AIA::Tools

  meta(
    name:     'mods2',
    role:     :backend,
    desc:     'AI on the command-line',
    url:      'https://github.com/charmbracelet/mods',
    install:  'brew install mods',
  )


  DEFAULT_PARAMETERS = ["--no-limit"].freeze

  attr_accessor :command, :extra_options, :text, :files

  def initialize(extra_options: "", text: "", files: [])
    # SMELL: This can come from AIA.config.extra
    @extra_options  = extra_options
    @text           = text
    @files          = files

    build_command
  end


  def build_command
    parameters = DEFAULT_PARAMETERS.dup
    parameters << '-f'                      if ::AIA.config.markdown?
    parameters << "-m #{AIA.config.model}"  if AIA.config.model
    parameters << @extra_options            unless @extra_options.empty?

    @command = ['mods', parameters.join(' ')].join(' ')
    
    # Use Tempfile to handle the text input to avoid CLI history pollution
    @tempfile = Tempfile.new('mods_prompt')
    @tempfile.write(@text)
    @tempfile.close

    @files.prepend @tempfile.path

    @files.each do |file|
      @command += " < #{file}"
    end
    
    @command
  end


  def run
    result = `#{@command}`
    @tempfile.unlink # Ensure tempfile is deleted after execution
    result
  end


  private

  attr_reader :tempfile
end
