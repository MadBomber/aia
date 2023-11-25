# lib/aia/cli.rb

module AIA::Cli
  def setup_cli_options(args)
    @arguments  = args
    @options    = {
      #           Value
      edit?:      [false, "-e --edit",    "Edit the Prompt File"],
      debug?:     [false, "-d --debug",   "Turn On Debugging"],
      verbose?:   [false, "-v --verbose", "Be Verbose"],
      version?:   [false, "--version",    "Print Version"],
      help?:      [false, "-h --help",    "Show Usage"],
      fuzzy?:     [false, "--fuzzy",      "Use Fuzzy Matching"],
      # TODO: Consider dropping output in favor of always
      #       going to STDOUT so user can redirect or pipe somewhere else
      output:     [OUTPUT,"-o --output --no-output",  "Out FILENAME"],
      log:        [PROMPT_LOG,"-l --log --no-log", "Log FILEPATH"],
      markdown?:  [true,  "-m --markdown --no-markdown --md --no-md", "Format with Markdown"],
    }
    
    # Array(String)
    @extra_options = [] # intended for the backend AI processor

    build_reader_methods # for the @options keys      
    process_arguments
  end


  def usage
    usage =   "\n#{MY_NAME} v#{AIA::VERSION}\n\n"
    usage +=  "Usage:  #{MY_NAME} [options] prompt_id [context_file]* [-- external_options+]\n\n"
    usage +=  usage_options
    usage += "\n"
    usage += usage_notes if verbose?
    
    usage
  end
 

  def usage_options
    options = [
      "Options",
      "-------",
      ""
    ]

    max_size = @options.values.map{|o| o[2].size}.max + 2

    @options.values.each do |o|
      pad_size = max_size - o[2].size
      options << o[2] + (" "*pad_size) + o[1]

      default = o[0]
      default = "./" + default.basename.to_s if o[1].include?('output')
      default = default.is_a?(Pathname) ? "$HOME/" + default.relative_path_from(HOME).to_s : default

      options << " default: #{default}\n"
    end

    options.join("\n")
  end


  def usage_notes
    <<~EOS
      #{usage_envars}
      #{AIA::ExternalCommands::HELP}
    EOS
  end


  def usage_envars
    <<~EOS
      System Environment Variables Used
      ---------------------------------

      The OUTPUT and PROMPT_LOG envars can be overridden
      by cooresponding options on the command line.

      Name            Default Value
      --------------  -------------------------
      PROMPTS_DIR     $HOME/.prompts_dir
      AI_CLI_PROGRAM  mods
      EDITOR          edit
      MODS_MODEL      gpt-4-1106-preview
      OUTPUT          ./temp.md
      PROMPT_LOG      $PROMPTS_DIR/_prompts.log

      These two are required for access the OpenAI
      services.  The have the same value but different
      programs use different envar names.

      To get an OpenAI access key/token (same thing)
      you must first create an account at OpenAI.
      Here is the link:  https://platform.openai.com/docs/overview

      OPENAI_ACCESS_TOKEN
      OPENAI_API_KEY

    EOS
  end


  def build_reader_methods
    @options.keys.each do |key|
      define_singleton_method(key) do
        @options[key][0]
      end
    end
  end


  def process_arguments
    @options.keys.each do |option|
      check_for option
    end

    # get the options meant for the backend AI command
    extract_extra_options

    bad_options = @arguments.select{|a| a.start_with?('-')}

    unless bad_options.empty?
      puts <<~EOS

        ERROR: Unknown options: #{bad_options.join(' ')}

      EOS
      
      show_usage

      exit
    end
  end


  def check_for(option_sym)
    boolean = option_sym.to_s.end_with?('?')
    switches = @options[option_sym][1].split

    switches.each do |switch|
      if @arguments.include?(switch)
        index = @arguments.index(switch)

        if boolean
          @options[option_sym][0] = switch.include?('-no-') ? false : true
          @arguments.slice!(index,1)
        else
          if switch.include?('-no-')
            @options[option_sym][0] = nil
            @arguments.slice!(index,1)
          else
            @options[option_sym][0] = @arguments[index + 1]
            @arguments.slice!(index,2)
          end
        end
        
        break
      end
    end
  end



  def show_usage
    @options[:help?][0] = false 
    puts usage
    exit
  end
  alias_method :show_help, :show_usage


  def show_version
    puts AIA::VERSION
    exit
  end


end
