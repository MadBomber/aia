# lib/aia/cli.rb

module AIA::Cli
  def setup_options(args)
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
    usage += usage_notes
    
    usage
  end
 

  def usage_options
    options = [
      "Options",
      "-------",
      ""
    ]
    @options.values.each do |o|
      options << o[1] + "\t" + o[2]
    end

    options.join("\n")
  end


  def usage_notes
    <<~EOS

      Notes
      -----

      To install the external CLI programs used by #{MY_NAME}:
        brew install mods ripgrep fzf

      #{AIA::ExternalCommands::HELP}
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
    puts usage
    exit
  end


  def show_version
    puts AIA::VERSION
    exit
  end


end
