# lib/aia.rb

require 'amazing_print'
require 'pathname'
require 'readline'
require 'tempfile'


require 'debug_me'
include DebugMe

$DEBUG_ME = true # ARGV.include?("--debug") || ARGV.include?("-d")

require 'prompt_manager'
require 'prompt_manager/storage/file_system_adapter'

require_relative "aia/version"
require_relative "core_ext/string_wrap"

module AIA
  class Main
    HOME            = Pathname.new(ENV['HOME'])
    PROMPTS_DIR     = Pathname.new(ENV['PROMPTS_DIR'] || (HOME + ".prompts_dir"))
    
    AI_CLI_PROGRAM  = "mods"
    EDITOR          = ENV['EDITOR'] || 'edit'
    MY_NAME         = Pathname.new(__FILE__).basename.to_s.split('.')[0]
    MODS_MODEL      = ENV['MODS_MODEL'] || 'gpt-4-1106-preview'
    OUTPUT          = Pathname.pwd + "temp.md"
    PROMPT_LOG      = PROMPTS_DIR  + "_prompts.log"


    # TODO: write the usage text
    USAGE = <<~EOUSAGE
      AI Assistant (aia)
      ==================

      The AI cli program being used is: #{AI_CLI_PROGRAM}

      You can pass additional CLI options to #{AI_CLI_PROGRAM} like this:
      "#{MY_NAME} my options -- options for #{AI_CLI_PROGRAM}"
    EOUSAGE


    def initialize(args= ARGV)
      @prompt     = nil
      @arguments  = args
      @options    = {
        edit?:      false,
        debug?:     false,
        verbose?:   false,
        version?:   false,
        help?:      false,
        fuzzy?:     false,
        markdown?:  true,
        output:     OUTPUT,
        log:        PROMPT_LOG,
      }
      @extra_options = [] # intended for the backend AI processor

      build_reader_methods # for the @options keys      
      process_arguments

      PromptManager::Prompt.storage_adapter = 
        PromptManager::Storage::FileSystemAdapter.config do |config|
          config.prompts_dir        = PROMPTS_DIR
          config.prompt_extension   = '.txt'
          config.params_extension   = '.json'
          config.search_proc        = nil
          # TODO: add the rgfzz script for search_proc
        end.new

      setup_cli_program
    end


    def build_reader_methods
      @options.keys.each do |key|
        define_singleton_method(key) do
          @options[key]
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


    def check_for(an_option)
      switches = [
        "--#{an_option}".gsub('?',''),    # Dropping ? in case of a boolean
        "--no-#{an_option}".gsub('?',''),
        "-#{an_option.to_s[0]}"  # SMELL: -v for both --verbose and --version
      ]

      process_option(an_option, switches)
    end


    def process_option(option_sym, switches)
      boolean = option_sym.to_s.end_with?('?')

      switches.each do |switch|
        if @arguments.include?(switch)
          index = @arguments.index(switch)

          if boolean
            @options[option_sym] = switch.include?('-no-') ? false : true
            @arguments.slice!(index,1)
          else
            if switch.include?('-no-')
              @option[option_sym] = nil
              @arguments.slice!(index,1)
            else
              @option[option_sym] = @arguments[index + 1]
              @arguments.slice!(index,2)
            end
          end
          
          break
        end
      end
    end


    def show_usage
      puts USAGE
      exit
    end


    def show_version
      puts VERSION
      exit
    end


    def call
      show_usage    if help?
      show_version  if version?

      prompt_id = get_prompt_id

      search_for_a_matching_prompt(prompt_id) unless existing_prompt?(prompt_id)
      process_prompt
      execute_and_log_command(build_command)
    end


    ####################################################
    private

    # Setup the AI CLI program with necessary variables
    def setup_cli_program

      ai_default_opts = "-m #{MODS_MODEL} --no-limit "
      ai_default_opts += "-f " if markdown?
      @ai_options     = ai_default_opts.dup


      @ai_options     += @extra_options.join(' ') 

      @ai_command     = "#{AI_CLI_PROGRAM} #{@ai_options} "
    end


    # Get the additional CLI arguments intended for the
    # backend gen-AI processor.
    def extract_extra_options
      extra_index = @arguments.index('--')
      if extra_index.nil?
        @extra_options = []
      else
        @extra_options = @arguments.slice!(extra_index..-1)[1..]
      end
    end


    # Fetch the first argument which should be the prompt id
    def get_prompt_id
      prompt_id = @arguments.shift

      # TODO: or maybe go to a search and select process

      abort("Please provide a prompt id") unless prompt_id
      prompt_id
    end


    # Check if a prompt with the given id already exists
    def existing_prompt?(prompt_id)
      @prompt = PromptManager::Prompt.get(id: prompt_id)
      true
    rescue ArgumentError
      false
    end


    # Process the prompt's associated keywords and parameters
    def process_prompt
      unless @prompt.keywords.empty?
        replace_keywords
        @prompt.build
        @prompt.save
      end
    end


    def replace_keywords
      print "\nQuit #{MY_NAME} with a CNTL-D or a CNTL-C\n\n"
      
      defaults = @prompt.parameters

      @prompt.keywords.each do |kw|
        defaults[kw] = keyword_value(kw, defaults[kw])
      end

      @prompt.parameters = defaults
    end


    # query the user for a value to the keyword allow the
    # reuse of the previous value shown as the default
    def keyword_value(kw, default)
      label = "Default: "
      puts "Parameter #{kw} ..."
      default_wrapped = default.wrap(indent: label.size)
      default_wrapped[0..label.size] = label
      puts default_wrapped

      begin
        a_string = Readline.readline("\n-=> ", false)
      rescue Interrupt
        a_string = nil
      end

      if a_string.nil?
        puts "okay. Come back soon."
        exit
      end


      puts
      a_string.empty? ? default : a_string
    end


    # Search for a prompt with a matching id or keyword
    def search_for_a_matching_prompt(prompt_id)
      # TODO: using the rgfzf version of the search_proc should only
      #       return a single prompt_id
      found_prompts = PromptManager::Prompt.search(prompt_id)
      prompt_id     = found_prompts.size == 1 ? found_prompts.first : handle_multiple_prompts(found_prompts, prompt_id)
      @prompt       = PromptManager::Prompt.get(id: prompt_id)
    end


    def handle_multiple_prompts(found_these, while_looking_for_this)
      raise ArgumentError, "Argument is not an Array" unless found_these.is_a?(Array)
      
      # TODO: Make this a class constant for defaults; make the header content
      #       a parameter so it can be varied.
      fzf_options       = [
        "--tabstop=2",  # 2 soaces for a tab
        "--header='Prompt IDs which contain: #{while_looking_for_this}\nPress ESC to cancel.'",
        "--header-first",
        "--prompt='Search term: '",
        '--delimiter :',
        "--preview 'cat $PROMPTS_DIR/{1}.txt'",
        "--preview-window=down:50%:wrap"
      ].join(' ') 


      # Create a temporary file to hold the list of strings
      temp_file = Tempfile.new('fzf-input')

      begin
        # Write all strings to the temp file
        temp_file.puts(found_these)
        temp_file.close

        # Execute fzf command-line utility to allow selection
        selected = `cat #{temp_file.path} | fzf #{fzf_options}`.strip

        # Check if fzf actually returned a string; if not, return nil
        result = selected.empty? ? nil : selected
      ensure
        # Ensure that the tempfile is closed and unlinked
        temp_file.unlink
      end

      exit unless result

      result
    end


    # Build the command to interact with the AI CLI program
    def build_command
      command = @ai_command + %Q["#{@prompt.to_s}"]

      @arguments.each do |input_file|
        file_path = Pathname.new(input_file)
        abort("File does not exist: #{input_file}") unless file_path.exist?
        command += " < #{input_file}"
      end

      command
    end


    # Execute the command and log the results
    def execute_and_log_command(command)
      puts command if verbose?
      result = `#{command}`
      output.write result

      write_to_log(result) unless log.nil?
    end


    def write_to_log(answer)
      f = File.open(log, "ab")

      f.write <<~EOS
        =======================================
        == #{Time.now}
        == #{@prompt.path}

        PROMPT:
        #{@prompt}

        RESULT:
        #{answer}

      EOS
    end
  end
end


# Create an instance of the Main class and run the program
AIA::Main.new.call if $PROGRAM_NAME == __FILE__


__END__


# TODO: Consider using this history process to preload the default
#       so that an up arrow will bring the previous answer into
#       the read buffer for line editing.
#       Instead of usin the .history file just push the default
#       value from the JSON file.

while input = Readline.readline('> ', true)
  # Skip empty entries and duplicates
  if input.empty? || Readline::HISTORY.to_a[-2] == input
    Readline::HISTORY.pop
  end
  break if input == 'exit'

  # Do something with the input
  puts "You entered: #{input}"

  # Save the history in case you want to preserve it for the next sessions
  File.open('.history', 'a') { |f| f.puts(input) }
end

# Load history from file at the beginning of the program
if File.exist?('.history')
  File.readlines('.history').each do |line|
    Readline::HISTORY.push(line.chomp)
  end
end


