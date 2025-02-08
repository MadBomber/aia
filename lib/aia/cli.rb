# lib/aia/cli.rb

HOME    = Pathname.new(ENV['HOME'])
MY_NAME = 'aia'


require 'hashie'
require 'pathname'
require 'yaml'
require 'toml-rb'


class AIA::Cli
  CF_FORMATS    = %w[yml yaml toml]
  ENV_PREFIX    = self.name.split('::').first.upcase + "_"
  MAN_PAGE_PATH = Pathname.new(__dir__) + '../../man/aia.1'
  

  def initialize(args)
    args = args.split(' ') if args.is_a?(String)
    @options = {
      arguments: args.is_a?(Array) ? args : [args],
      directives: [[]],
      editor:     [ENV['EDITOR'], ""],
      model:        ["gpt-4o",  "--llm --model"],
      code_model:   ["claude-3-5-sonnet", "--cm --code_model"],
      speech_model: ["tts-1",   "--sm --speech_model"],
      voice:        ["alloy",   "--voice"],
      transcription_model:  ["whisper-1", "--tm --transcription_model"],
      dump_file:  [nil,       "--dump"],
      completion: [nil,       "--completion"],
      chat?:      [false,     "--chat"],
      debug?:     [false,     "-d --debug"],
      erb?:       [false,     "--erb"],
      fuzzy?:     [false,     "-f --fuzzy"],
      help?:      [false,     "-h --help"],
      markdown?:  [true,      "-m --markdown --no-markdown --md --no-md"],
      render?:    [false,     "--render"],
      shell?:     [false,     "--shell"],
      speak?:     [false,     "--speak"],
      terse?:     [false,     "--terse"],
      verbose?:   [false,     "-v --verbose"],
      version?:   [false,     "--version"],
      next:       ['',        "-n --next"],
      pipeline:   [[],        "--pipeline"],
      role:       ['',        "-r --role"],
      config_file:[nil,                       "-c --config_file"],
      prompts_dir:["~/.prompts",              "-p --prompts_dir"],
      roles_dir:  ["~/.prompts/roles",        "--roles_dir"],
      out_file:   [STDOUT,                    "-o --out_file --no-out_file"],
      log_file:   ["~/.prompts/_prompts.log", "-l --log_file --no-log_file"],
      image_model:    ['dall-e-3',  '--im --image_model'],
      image_size:     ['',          '--is --image_size'],
      image_quality:  ['',          '--iq --image_quality'],
      audio_model:    ['whisper-1',   '--am --audio_model'],
      audio_size:     ['',            '--as --audio_size'],
      audio_quality:  ['',            '--aq --audio_quality'],
    }
    # Preserve full positional arguments for :arguments
    config_options = {}
    @options.each do |key, value|
      config_options[key] = (key == :arguments ? value : value.first)
    end
    AIA.config = AIA::Config.new(config_options)
  end


  def convert_pathname_objects!(converting_to_pathname: true)
    path_keys = AIA.config.keys.grep(/_(dir|file)\z/)
    path_keys.each do |key|
      case AIA.config[key]
      when String
        AIA.config[key] = string_to_pathname(AIA.config[key])
      when Pathname
        AIA.config[key] = pathname_to_string(AIA.config[key]) unless converting_to_pathname
      end
    end
  end


  def error_on_invalid_option_combinations
    if (AIA.config.respond_to?(:chat?) ? AIA.config.chat? : AIA.config.chat)
      if !AIA.config.next.empty?
        abort "ERROR: Cannot use --next with --chat"
      end
      if AIA.config.out_file != STDOUT
        abort "ERROR: Cannot use --out_file with --chat"
      end
      if !AIA.config.pipeline.empty?
        abort "ERROR: Cannot use --pipeline with --chat"
      end
    end

    unless AIA.config.next.empty?
      unless AIA.config.pipeline.empty?
        abort "ERROR: Cannot use --pipeline with --next"
      end
    end
  end

  def string_to_pathname(string)
    ['~/', '$HOME/'].each do |prefix|
      if string.start_with? prefix
        string = string.gsub(prefix, HOME.to_s+'/')
        break
      end
    end

    pathname = Pathname.new(string)
    pathname.relative? ? Pathname.pwd + pathname : pathname
  end


  def pathname_to_string(pathname)
    pathname.to_s
  end


  def convert_to_pathname_objects
    convert_pathname_objects!(converting_to_pathname: true)
  end


  def convert_from_pathname_objects
    convert_pathname_objects!(converting_to_pathname: false)
  end


  def load_env_options
    known_keys = @options.keys

    keys  = ENV.keys
              .select{|k| k.start_with?(ENV_PREFIX)}
              .map{|k| k.gsub(ENV_PREFIX,'').downcase.to_sym}

    keys.each do |key|
      envar_key       = ENV_PREFIX + key.to_s.upcase
      if known_keys.include?(key)
        AIA.config[key] = ENV[envar_key]
      elsif known_keys.include?("#{key}?".to_sym)
        key = "#{key}?".to_sym
        AIA.config[key] = %w[true t yes yea y 1].include?(ENV[envar_key].strip.downcase) ? true : false
      else
        # This is a new config key
        AIA.config[key] = ENV[envar_key]
      end
    end
  end


  def replace_erb_in_config_file
    content = Pathname.new(AIA.config.config_file).read
    content = ERB.new(content).result(binding)
    AIA.config.config_file  = AIA.config.config_file.to_s.gsub('.erb', '')
    Pathname.new(AIA.config.config_file).write content
  end


  def load_config_file
    if AIA.config.config_file.to_s.end_with?(".erb")
      replace_erb_in_config_file
    end

    AIA.config.config_file = Pathname.new(AIA.config.config_file)
    if AIA.config.config_file.exist?
      AIA.config.merge! parse_config_file
    else
      abort "Config file does not exist: #{AIA.config.config_file}"
    end
  end


  def setup_options_with_defaults(args)
    # TODO: This structure if flat; consider making it
    #       at least two levels totake advantage of
    #       YAML and TOML capabilities to isolate
    #       common options within a section.
    #
    @options    = {
      #           Default
      # Key       Value,      switches
      arguments:  [args], # NOTE: after process, prompt_id and context_files will be left
      directives: [[]],   # an empty Array as the default value
      editor:     [ENV['EDITOR'], ""],
      #
      model:        ["gpt-4o",  "--llm --model"],
      code_model:   ["claude-3-5-sonnet", "--cm --code_model"],
      speech_model: ["tts-1",   "--sm --speech_model"],
      voice:        ["alloy",   "--voice"],
      #
      transcription_model:  ["whisper-1", "--tm --transcription_model"],
      #
      dump_file:  [nil,       "--dump"],
      completion: [nil,       "--completion"],
      #
      chat?:      [false,     "--chat"],
      debug?:     [false,     "-d --debug"],
      erb?:       [false,     "--erb"],
      fuzzy?:     [false,     "-f --fuzzy"],
      help?:      [false,     "-h --help"],
      markdown?:  [true,      "-m --markdown --no-markdown --md --no-md"],
      render?:    [false,     "--render"],
      shell?:     [false,     "--shell"],
      speak?:     [false,     "--speak"],
      terse?:     [false,     "--terse"],
      verbose?:   [false,     "-v --verbose"],
      version?:   [false,     "--version"],
      #
      next:       ['',        "-n --next"],
      pipeline:   [[],        "--pipeline"],
      role:       ['',        "-r --role"],
      #
      config_file:[nil,                       "-c --config_file"],
      prompts_dir:["~/.prompts",              "-p --prompts_dir"],
      roles_dir:  ["~/.prompts/roles",        "--roles_dir"],
      out_file:   [STDOUT,                    "-o --out_file --no-out_file"],
      log_file:   ["~/.prompts/_prompts.log", "-l --log_file --no-log_file"],
      #
      # text2image related ...
      #
      image_model:    ['dall-e-3',  '--im --image_model'],
      image_size:     ['',          '--is --image_size'],
      image_quality:  ['',          '--iq --image_quality'],
      #
      # audio related ...
      #
      audio_model:    ['whisper-1',   '--am --audio_model'],
      audio_size:     ['',            '--as --audio_size'],
      audio_quality:  ['',            '--aq --audio_quality'],
    }
    
    AIA.config = AIA::Config.new(@options.transform_values { |values| values.first })
  end


  def arguments
    AIA.config.arguments
  end


  def execute_immediate_commands
    show_usage        if AIA.config.help?
    show_version      if AIA.config.version?
    dump_config_file  if AIA.config.dump_file
    show_completion   if AIA.config.completion
  end


  def dump_config_file
    a_hash    = prepare_config_as_hash

    dump_file = Pathname.new AIA.config.dump_file
    extname   = dump_file.extname.to_s.downcase

    case extname
    when '.yml', '.yaml'
      dump_file.write YAML.dump(a_hash)
    when '.toml'
      dump_file.write TomlRB.dump(a_hash)
    else
      abort "Invalid config file format (#{extname}) request.  Only #{CF_FORMATS.join(', ')} are supported."
    end

    exit
  end


  def prepare_config_as_hash
    convert_from_pathname_objects
    
    a_hash          = AIA.config.to_h
    a_hash['dump']  = nil

    %w[ arguments config_file dump_file ].each do |unwanted_key|
      a_hash.delete(unwanted_key)
    end
    
    a_hash
  end


  def process_command_line_arguments
    @options.keys.each do |option|
      check_for option
    end

    bad_options = arguments.select{|a| a.start_with?('-')}

    unless bad_options.empty?
      puts <<~EOS

        ERROR: Unknown options: #{bad_options.join(' ')}

      EOS
      
      show_error_usage

      exit
    end
  
    # After all other arguments 
    # are processed, check for role parameter.
    check_for_role_parameter
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
            AIA.config[option_sym] = switch.include?('out_file') ? STDOUT : nil
            arguments.slice!(index,1)
          else
            value = arguments[index + 1]
            if value.nil? || value.start_with?('-')
              abort "ERROR: #{option_sym} requires a parameter value"
            elsif "--pipeline" == switch
              prompt_sequence = value.split(',')
              AIA.config[option_sym] = prompt_sequence
              arguments.slice!(index,2)
            else
              AIA.config[option_sym] = value
              arguments.slice!(index,2)
            end
          end
        end
        
        break
      end
    end
  end


  def check_for_role_parameter
    role = AIA.config.role
    return if role.empty?

    role_path = string_to_pathname(AIA.config.roles_dir) + "#{role}.txt"

    unless role_path.exist?
      puts "Role prompt '#{role}' not found. Invoking fzf to choose a role..."
      invoke_fzf_to_choose_role
    end
  end


  def invoke_fzf_to_choose_role
    roles_path = string_to_pathname AIA.config.roles_dir

    available_roles = roles_path
                        .children
                        .select { |f| '.txt' == f.extname}
                        .map{|role| role.basename.to_s.gsub('.txt','')}
    
    fzf = AIA::Fzf.new(
      list:       available_roles,
      directory:  roles_path,
      prompt:     'Select Role:',
      extension:  '.txt'
    )

    chosen_role = fzf.run

    if chosen_role.nil?
      abort("No role selected. Exiting...")
    else
      AIA.config.role = chosen_role
      puts "Role changed to '#{chosen_role}'."
    end
  end


  def show_error_usage
    puts <<~ERROR_USAGE

      Usage: aia [options] PROMPT_ID [CONTEXT_FILE(s)] [-- EXTERNAL_OPTIONS]"
      Try 'aia --help' for more information."
    
    ERROR_USAGE
  end


  # aia usage is maintained in a man page
  def show_usage
    @options[:help?][0] = false 
    puts `man #{MAN_PAGE_PATH}`
    exit
  end
  alias_method :show_help, :show_usage


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
        config.prompts_dir        = AIA.config.prompts_dir
        config.prompt_extension   = '.txt'
        config.params_extension   = '.json'
        config.search_proc        = nil
        # TODO: add the rgfzf script for search_proc
      end.new
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
