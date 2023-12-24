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
  CF_FORMATS    = %w[yml yaml toml]
  ENV_PREFIX    = self.name.split('::').first.upcase + "_"
  MAN_PAGE_PATH = Pathname.new(__dir__) + '../../man/aia.1'
  

  # attr_accessor :config
  # attr_accessor :options

  def initialize(args)
    setup_options_with_defaults(args) # 1. defaults
    load_env_options                  # 2. over-ride with envars
    process_command_line_arguments    # 3. over-ride with command line options

    # 4. over-ride everything with config file
    load_config_file unless AIA.config.config_file.nil?

    setup_prompt_manager

    process_immediate_commands
  end


  def load_env_options
    keys  = ENV.keys
              .select{|k| k.start_with?(ENV_PREFIX)}
              .map{|k| k.gsub(ENV_PREFIX,'').downcase.to_sym}

    keys.each do |key|
      envar_key       = ENV_PREFIX + key.to_s.upcase
      AIA.config[key] = ENV[envar_key]
    end
  end


  def load_config_file
    AIA.config.config_file = Pathname.new(AIA.config.config_file)
    if AIA.config.config_file.exist?
      AIA.config.merge! parse_config_file
    else
      abort "Config file does not exist: #{AIA.config.config_file}"
    end
  end


  def setup_options_with_defaults(args)
    @options    = {
      #           Default
      # Key       Value,      switches
      arguments:  [args],
      extra:      [''],
      config_file:[nil,       "-c --config"],
      dump:       [nil,       "--dump"],
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
    
    AIA.config = Hashie::Mash.new(@options.transform_values { |values| values.first })
  end


  def arguments
    AIA.config.arguments
  end


  def process_immediate_commands
    show_usage        if AIA.config.help?
    show_version      if AIA.config.version?
    dump_config_file  if AIA.config.dump
    show_completion   if AIA.config.completion
  end


  def dump_config_file
    a_hash = prepare_config_as_hash

    case AIA.config.dump.downcase
    when 'yml', 'yaml'
      puts YAML.dump(a_hash)
    when 'toml'
      puts TomlRB.dump(a_hash)
    else
      abort "Invalid config file format request.  Only #{CF_FORMATS.join(', ')} are supported."
    end

    exit
  end


  def prepare_config_as_hash
    a_hash          = AIA.config.to_h
    a_hash['dump']  = nil

    # convert Pathname objects to Strings
    %w[log output].each do |key|
      a_hash[key] = a_hash[key].to_s
    end

    a_hash.delete('arguments')

    a_hash
  end


  def process_command_line_arguments
    @options.keys.each do |option|
      check_for option
    end

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
          AIA.config[option_sym] = switch.include?('-no-') ? false : true
          arguments.slice!(index,1)
        else
          if switch.include?('-no-')
            AIA.config[option_sym] = switch.include?('output') ? STDOUT : nil
            arguments.slice!(index,1)
          else
            AIA.config[option_sym] = arguments[index + 1]
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
  # alias_method :show_verbose_help, :show_verbose_usage


  def show_completion
    shell   = AIA.config.completion
    script  = Pathname.new(__dir__) + "aia_completion.#{shell}"

    if script.exist?
      puts
      puts script.read
      puts
    else
      STDERR.puts <<~EOS

        ERROR: The shell '#{shell}' is not supported.

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

__END__

```markdown
In the `AIA::Cli` class, methods are currently ordered in a mostly procedural 
manner. However, making a few adjustments could improve readability and 
maintainability. Here's an updated organization that helps to group relevant 
methods together, and ensure that crucial lifecycle methods like `initialize` 
are easily found:

1. **Initialization and Setup Methods:**
   These methods initialize the CLI and perform initial configuration. 
   It's useful to keep them at the top as they provide an overview of 
   the CLI setup sequence.

   - `initialize(args)`
   - `setup_options_with_defaults(args)`
   - `load_env_options`
   - `process_command_line_arguments`
   - `load_config_file`
   - `setup_prompt_manager`
   - `process_immediate_commands`

2. **Primary Public Methods:**
   These are the methods that form the primary public interface of the class, 
   aside from `initialize`, which is already listed above.

   - None in the current implementation, but this is where you would list them 
   if they were present.

3. **Config Processing Methods:**
   These methods are involved in handling and processing CLI and configuration 
   options.

   - `arguments`
   - `check_for(option_sym)`
   - `dump_config_file`
   - `prepare_config_as_hash`
   - `extract_extra_options`
   - `parse_config_file`

4. **Immediate Command Methods:**
   These methods handle immediate actions and are called directly from `
   initialize`, such as showing usage or version.

   - `show_usage` (and the `show_help` alias)
   - `show_verbose_usage`
   - `show_completion`
   - `show_version`

5. **Utility and Private Methods:**
   Any further utility or private helper methods would come here, aiding the 
   primary public methods.

   - Currently, there are no explicit utility/private methods defined, but if 
   present, they would be positioned here.

By grouping methods in this way, it becomes clearer to see the execution flow and lifecycle of the `AIA::Cli` class. It also makes it easier to understand the dependencies between methods and to follow the logic for someone maintaining the code or for a new developer coming onto the project.

Furthermore, it is a common Ruby convention to have the `initialize` method at 
the top of the class definition, followed by other lifecycle methods, public 
methods, and finally private or protected methods.

Note that this is a refactoring focused on method order and does not include 
scrutinizing the internals of the methods themselves. There's also an assumption 
made that there's no direct dependency on the order for the current runtime 
behavior; changing the order shouldn't affect the runtime if all methods are 
designed to be independent.
```

