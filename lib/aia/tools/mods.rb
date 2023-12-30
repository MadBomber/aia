# lib/aia/tools/mods.rb

class AIA::Mods < AIA::Tools

  meta(
    name:     'mods',
    role:     :backend,
    desc:     'AI on the command-line',
    url:      'https://github.com/charmbracelet/mods',
    install:  'brew install mods',
  )

  
  DEFAULT_PARAMETERS = [
    # "--no-cache",           # do not save prompt and response
    "--no-limit"              # no limit on input context
  ].join(' ').freeze

  attr_accessor :command, :text, :files


  def initialize(
      text:           "", # prompt text after keyword replacement
      files:          []  # context file paths (Array of Pathname)
    )

    @text           = text
    @files          = files

    build_command
  end


  def sanitize(input)
    Shellwords.escape(input)
  end


  def build_command
    parameters  = DEFAULT_PARAMETERS.dup + " "
    parameters += "-f "                     if AIA.config.markdown?
    parameters += "-m #{AIA.config.model} " if AIA.config.model
    parameters += AIA.config.extra
    @command    = "mods #{parameters} "
    @command   += sanitize(@text)

    # context = @files.join(' ')
    #
    # unless context.empty?
    #   if @files.size > 1
    #     # FIXME:  This syntax breaks mods which does not know how
    #     #         to read the temporary file descriptor created
    #     #         by the shell
    #     @command += " <(cat #{context})"
    #   else
    #     @command += " < #{context}"
    #   end
    # end

    @command
  end


  def run
    case @files.size
    when 0
      @result = `#{build_command}`
    when 1
      @result = `#{build_command} < #{@files.first}`
    else
      create_temp_file_with_contexts
      run_mods_with_temp_file
      clean_up_temp_file
    end
    
    @result
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
  

  # Run 'mods' with the temporary file as STDIN
  def run_mods_with_temp_file
    command = "#{build_command} < #{@temp_file.path}"
    @result = `#{command}`
  end
  

  # Clean up the temporary file after use
  def clean_up_temp_file
    @temp_file.unlink if @temp_file
  end
end

__END__


    


##########################################################


GPT on the command line. Built for pipelines.

Usage:
  mods [OPTIONS] [PREFIX TERM]

Options:
  -m, --model                                  Default model (gpt-3.5-turbo, gpt-4, ggml-gpt4all-j...).
  -a, --api                                    OpenAI compatible REST API (openai, localai).
  -x, --http-proxy                             HTTP proxy to use for API requests.
  -f, --format                                 Ask for the response to be formatted as markdown unless otherwise set.
  -r, --raw                                    Render output as raw text when connected to a TTY.
  -P, --prompt                                 Include the prompt from the arguments and stdin, truncate stdin to specified number of lines.
  -p, --prompt-args                            Include the prompt from the arguments in the response.
  -c, --continue                               Continue from the last response or a given save title.
  -C, --continue-last                          Continue from the last response.
  -l, --list                                   Lists saved conversations.
  -t, --title                                  Saves the current conversation with the given title.
  -d, --delete                                 Deletes a saved conversation with the given title or ID.
  -s, --show                                   Show a saved conversation with the given title or ID.
  -S, --show-last                              Show a the last saved conversation.
  -q, --quiet                                  Quiet mode (hide the spinner while loading and stderr messages for success).
  -h, --help                                   Show help and exit.
  -v, --version                                Show version and exit.
  --max-retries                                Maximum number of times to retry API calls.
  --no-limit                                   Turn off the client-side limit on the size of the input into the model.
  --max-tokens                                 Maximum number of tokens in response.
  --temp                                       Temperature (randomness) of results, from 0.0 to 2.0.
  --topp                                       TopP, an alternative to temperature that narrows response, from 0.0 to 1.0.
  --fanciness                                  Your desired level of fanciness.
  --status-text                                Text to show while generating.
  --no-cache                                   Disables caching of the prompt/response.
  --reset-settings                             Backup your old settings file and reset everything to the defaults.
  --settings                                   Open settings in your $EDITOR.
  --dirs                                       Print the directories in which mods store its data

Example:
  # Editorialize your video files
  ls ~/vids | mods -f "summarize each of these titles, group them by decade" | glow
