# lib/aia.rb

require 'readline'
require 'cli_helper'
require 'pathname'
require 'amazing_print'
require 'debug_me'
include DebugMe

require 'prompt_manager'
require 'prompt_manager/storage/file_system_adapter'


require_relative "aia/version"
require_relative "core_ext/string_wrap"

module AIA
  class Main
    HOME            = Pathname.new(ENV['HOME'])
    PROMPTS_DIR     = Pathname.new(ENV['PROMPTS_DIR'] || (HOME + ".prompts_dir"))
    MODS_MODEL      = ENV['MODS_MODEL'] || 'gpt-4-1106-preview'
    AI_CLI_PROGRAM  = "mods"
    PROMPT_LOG      = PROMPTS_DIR  + "_prompts.log"
    OUTPUT          = Pathname.pwd + "temp.md"
    EDITOR          = ENV['EDITOR'] || 'edit'

    USAGE = <<~EOUSAGE
      AI Assistant (aia)
      ==================

      The AI cli program being used is: #{AI_CLI_PROGRAM}

      You can pass additional CLI options to #{AI_CLI_PROGRAM} like this:
      "#{my_name} my options -- options for #{AI_CLI_PROGRAM}"
    EOUSAGE

    def initialize
      @prompt     = nil
      @arguments  = ARGV
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

      build_reader_methods # for the @options keys
      
      $DEBUG_ME = debug?

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
    end


    def check_for(an_option)
      option_str  = an_option.to_s
      switches    = []
      switches << "--#{option_str}"
      switches << "--no-#{option_str}"
      switches <M "-#{option_str[0]}"
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
            @option[option_sym] = @arguments[index + 1]
            @arguments.slice!(index,2)
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
      show_help     if help?
      show_version  if version?

      prompt_id = get_prompt_id
      search_for_a_matching_prompt(prompt_id) unless existing_prompt?(prompt_id)

      process_prompt(prompt_id)

      command = build_command(prompt_id)
      execute_and_log_command(command, prompt_id)
    end


    ####################################################
    private

    # Setup the AI CLI program with necessary variables
    def setup_cli_program
      ai_default_opts = "-m #{MODS_MODEL} --no-limit -f"
      @ai_options     = ai_default_opts.dup
      extract_extra_options
      @ai_command     = "#{AI_CLI_PROGRAM} #{@ai_options}"
    end


    # Fetch the first argument which should be the prompt id
    def get_prompt_id
      prompt_id = ARGV.shift

      # TODO: or maybe go to a search and select process

      abort("Please provide a prompt id") unless prompt_id
      prompt_id
    end


    # Check if a prompt with the given id already exists
    def existing_prompt?(prompt_id)
      PromptManager::Prompt.get(id: prompt_id)
      true
    rescue ArgumentError
      false
    end


    # Process the prompt's associated keywords and parameters
    def process_prompt(prompt_id)
      prompt = PromptManager::Prompt.get(id: prompt_id)

      unless prompt.keywords.empty?
        replace_keywords(prompt) 
        prompt.build
        prompt.save
      end
    end


    # Search for a prompt with a matching id or keyword
    def search_for_a_matching_prompt(prompt_id)
      found_prompts = PromptManager::Prompt.search(prompt_id)
      prompt_id = found_prompts.size == 1 ? found_prompts.first : handle_multiple_prompts(found_prompts, prompt_id)
      prompt = PromptManager::Prompt.get(id: prompt_id)
    end


    # Build the command to interact with the AI CLI program
    def build_command(prompt_id)
      prompt  = PromptManager::Prompt.get(id: prompt_id)
      command = @ai_command + prompt.to_s

      ARGV.each do |input_file|
        file_path = Pathname.new(input_file)
        abort("File does not exist: #{input_file}") unless file_path.exist?
        command += " < #{input_file}"
      end

      command
    end


    # Execute the command and log the results
    def execute_and_log_command(command, prompt_id)
      puts command if verbose?
      result = `#{command}`
      @output.write result

      log(prompt_id, result)
    end
  end
end


# Create an instance of the Main class and run the program
AIA::Main.new.call if $PROGRAM_NAME == __FILE__

