# lib/aia/tools/sgpt.rb

class AIA::Sgpt < AIA::Tools

  meta(
    name:     'sgpt',
    role:     :backend,
    desc:     "shell-gpt",
    url:      "https://github.com/TheR1D/shell_gpt",
    install:  "pip install shell-gpt",
  )


  DEFAULT_PARAMETERS = [
    # "--verbose",          # enable verbose logging (if applicable)
    # Add default parameters here
  ].join(' ').freeze

  DIRECTIVES = %w[
    model
    temperature
    max_tokens
    top_p
    frequency_penalty
    presence_penalty
    stop_sequence
    api_key
    # Add more directives if needed
  ]

  attr_accessor :command, :text, :files, :parameters

  def initialize(text: "", files: [])
    @text       = text
    @files      = files
    @parameters = DEFAULT_PARAMETERS.dup
    build_command
  end


  def sanitize(input)
    Shellwords.escape(input)
  end


  def build_command
    @parameters += " --model #{AIA.config.model} " if AIA.config.model
    @parameters += AIA.config.extra

    set_parameter_from_directives

    @command = "sgpt #{@parameters} "
    @command += sanitize(text)

    puts @command if AIA.config.debug?

    @command
  end


  # Clean up the temporary file after use
  def clean_up_temp_file
    @temp_file.unlink if @temp_file
  end


  def set_parameter_from_directives
    AIA.config.directives.each do |directive, value|
      if DIRECTIVES.include?(directive)
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


  # Run with the temporary file as STDIN
  def run_with_temp_file
    command = "#{build_command} < #{@temp_file.path}"
    @result = `#{command}`
  end
  

  # Create a temporary file that concatenates all contexts,
  # to be used as STDIN for the 'mods' utility
  def create_temp_file_with_contexts
    @temp_file = Tempfile.new('mods-context')

    @files.each do |file|
      content = File.read(file)
      @temp_file.write(content)
      @temp_file.write("\n")
    end

    @temp_file.close
  end
  

end

__END__
                                                                                               
 Usage: sgpt [OPTIONS] [PROMPT]                                                                
                                                                                               
╭─ Arguments ─────────────────────────────────────────────────────────────────────────────────╮
│   prompt      [PROMPT]  The prompt to generate completions for.                             │
╰─────────────────────────────────────────────────────────────────────────────────────────────╯
╭─ Options ───────────────────────────────────────────────────────────────────────────────────╮
│ --model                             TEXT                       Large language model to use. │
│                                                                [default: gpt-3.5-turbo]     │
│ --temperature                       FLOAT RANGE [0.0<=x<=2.0]  Randomness of generated      │
│                                                                output.                      │
│                                                                [default: 0.1]               │
│ --top-probability                   FLOAT RANGE [0.1<=x<=1.0]  Limits highest probable      │
│                                                                tokens (words).              │
│                                                                [default: 1.0]               │
│ --editor             --no-editor                               Open $EDITOR to provide a    │
│                                                                prompt.                      │
│                                                                [default: no-editor]         │
│ --cache              --no-cache                                Cache completion results.    │
│                                                                [default: cache]             │
│ --help                                                         Show this message and exit.  │
╰─────────────────────────────────────────────────────────────────────────────────────────────╯
╭─ Assistance Options ────────────────────────────────────────────────────────────────────────╮
│ --shell           -s                 Generate and execute shell commands.                   │
│ --describe-shell  -d                 Describe a shell command.                              │
│ --code                --no-code      Generate only code. [default: no-code]                 │
╰─────────────────────────────────────────────────────────────────────────────────────────────╯
╭─ Chat Options ──────────────────────────────────────────────────────────────────────────────╮
│ --chat                             TEXT  Follow conversation with id, use "temp" for quick  │
│                                          session.                                           │
│                                          [default: None]                                    │
│ --repl                             TEXT  Start a REPL (Read–eval–print loop) session.       │
│                                          [default: None]                                    │
│ --show-chat                        TEXT  Show all messages from provided chat id.           │
│                                          [default: None]                                    │
│ --list-chats    --no-list-chats          List all existing chat ids.                        │
│                                          [default: no-list-chats]                           │
╰─────────────────────────────────────────────────────────────────────────────────────────────╯
╭─ Role Options ──────────────────────────────────────────────────────────────────────────────╮
│ --role                              TEXT  System role for GPT model. [default: None]        │
│ --create-role                       TEXT  Create role. [default: None]                      │
│ --show-role                         TEXT  Show role. [default: None]                        │
│ --list-roles     --no-list-roles          List roles. [default: no-list-roles]              │
╰─────────────────────────────────────────────────────────────────────────────────────────────╯

