# lib/aia/cli.rb


HOME            = Pathname.new(ENV['HOME'])
PROMPTS_DIR     = Pathname.new(ENV['PROMPTS_DIR'] || (HOME + ".prompts_dir"))

AI_CLI_PROGRAM  = "mods"
MY_NAME         = "aia"
MODS_MODEL      = ENV['MODS_MODEL'] || 'gpt-4-1106-preview'
OUTPUT          = Pathname.pwd + "temp.md"
PROMPT_LOG      = PROMPTS_DIR  + "_prompts.log"


require 'hashie'
require 'pathname'
require 'yaml'
require 'toml-rb'


class AIA::Cli
  MAN_PAGE_PATH = Pathname.new(__dir__) + '../../man/aia.1'
  attr_accessor :config
  attr_accessor :options

  def initialize(args)
    setup_cli_options(args)

    load_config_file unless AIA.config.config_file.nil?

    setup_prompt_manager

    process_immediate_commands
  end


  def load_config_file
    AIA.config.config_file = Pathname.new(AIA.config.config_file)
    if AIA.config.config_file.exist?
      AIA.config.merge! parse_config_file
    else
      abort "Config file does not exist: #{AIA.config.config_file}"
    end
  end


  def setup_cli_options(args)
    @options    = {
      #           Default
      # Key       Value,      switches
      arguments:  [args],
      extra:      [''],
      config_file:[nil,       "-c --config"],
      dump?:      [false,     "--dump"],
      edit?:      [false,     "-e --edit"],
      debug?:     [false,     "-d --debug"],
      verbose?:   [false,     "-v --verbose"],
      version?:   [false,     "--version"],
      help?:      [false,     "-h --help"],
      fuzzy?:     [false,     "--fuzzy"],
      completion: [nil,       "--completion"],
      output:     [OUTPUT,    "-o --output --no-output"],
      log:        [PROMPT_LOG,"-l --log --no-log"],
      markdown?:  [true,      "-m --markdown --no-markdown --md --no-md"],
      backend:    ['mods',    "-b --be --backend --no-backend"],
    }
    
    # build_reader_methods # for the @options keys      
    process_arguments

    AIA.config = Hashie::Mash.new(@options.transform_values { |values| values.first })
  end


  def arguments
    @options[:arguments].first
  end


  def process_immediate_commands
    show_usage        if AIA.config.help?
    show_version      if AIA.config.version?
    dump_config_file  if AIA.config.dump?
  end


  def dump_config_file
    puts <<~EOS
      
      TODO: dump the @options hash to a
      config file.  Should it be TOML or YAML
      or either?  Should it go to STDOUT or to
      a specific file location.

    EOS

    exit
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

    show_completion unless @options[:completion].first.nil?

    # get the options meant for the backend AI command
    extract_extra_options

    bad_options = arguments.select{|a| a.start_with?('-')}

    unless bad_options.empty?
      puts <<~EOS

        ERROR: Unknown options: #{bad_options.join(' ')}

      EOS
      
      show_usage

      exit
    end
  end


  def check_for(option_sym)
    # sometimes @options has stuff that is not a command line option
    return if @options[option_sym].nil? || @options[option_sym].size <= 1

    boolean   = option_sym.to_s.end_with?('?')
    switches  = @options[option_sym][1].split

    switches.each do |switch|
      if arguments.include?(switch)
        index = arguments.index(switch)

        if boolean
          @options[option_sym][0] = switch.include?('-no-') ? false : true
          arguments.slice!(index,1)
        else
          if switch.include?('-no-')
            @options[option_sym][0] = nil
            arguments.slice!(index,1)
          else
            @options[option_sym][0] = arguments[index + 1]
            arguments.slice!(index,2)
          end
        end
        
        break
      end
    end
  end

  # aia usage is maintained in a man page
  def show_usage
    @options[:help?][0] = false 
    puts `man #{MAN_PAGE_PATH}`
    show_verbose_usage if AIA.config.verbose?
    exit
  end
  alias_method :show_help, :show_usage


  def show_verbose_usage
    puts <<~EOS

      ======================================
      == Currently selected Backend: #{AIA.config.backend} ==
      ======================================

    EOS
    puts `mods --help` if "mods" == AIA.config.backend
    puts `sgpt --help` if "sgpt" == AIA.config.backend
    puts
  end
  alias_method :show_verbise_help, :show_verbose_usage


  def show_completion
    shell   = @options[:completion].first
    script  = Pathname.new(__dir__) + "aia_completion.#{shell}"

    if script.exist?
      puts
      puts script.read
      puts
    else
      STDERR.puts <<~EOS

        ERRORL The shell '#{shell}' is not supported.

      EOS
    end


    exit    
  end


  def show_version
    puts AIA::VERSION
    exit
  end


  def setup_prompt_manager
    @prompt     = nil

    PromptManager::Prompt.storage_adapter = 
      PromptManager::Storage::FileSystemAdapter.config do |config|
        config.prompts_dir        = PROMPTS_DIR
        config.prompt_extension   = '.txt'
        config.params_extension   = '.json'
        config.search_proc        = nil
        # TODO: add the rgfzf script for search_proc
      end.new
  end


  # Get the additional CLI arguments intended for the
  # backend gen-AI processor.
  def extract_extra_options
    extra_index = arguments.index('--')
    if extra_index
      @options[:extra] = [ arguments.slice!(extra_index..-1)[1..].join(' ') ]
    end
  end


  def parse_config_file
    case AIA.config.config_file.extname.downcase
    when '.yaml', '.yml'
      YAML.safe_load(AIA.config.config_file.read)
    when '.toml'
      TomlRB.parse(AIA.config.config_file.read)
    else
      abort "Unsupported config file type: #{AIA.config.config_file.extname}"
    end
  end



end
