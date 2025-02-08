# lib/aia/main.rb

require_relative 'config'
require_relative 'setup_helpers'
require_relative 'cli'
require_relative 'client'
require_relative 'directives'
require_relative 'dynamic_content'
require_relative 'prompt'
require_relative 'logging'
require_relative 'tools'
require_relative 'user_query'
require_relative 'client_manager'
require_relative 'response_handler'
require_relative 'prompt_processor'
require_relative 'chat_manager'
require_relative 'pipeline_processor'
require_relative 'configuration_validator'

module AIA
  class Main
    include SetupHelpers

    SPINNER_FORMAT = :bouncing_ball

    include DynamicContent
    include UserQuery
    
    attr_accessor :logger, :tools, :directive_output, :piped_content
    attr_reader :spinner

    def initialize(args = ARGV)
      @piped_content = read_piped_content
      @directive_output = ""
      @args = args
      
      initialize_components
    end

    def call
      process_directives
      result = process_prompt
      handle_output(result)
      continue_processing(result) if continue?
    end

    private

    def read_piped_content
      return nil if $stdin.tty?
      content = $stdin.readlines.join.chomp
      $stdin.reopen("/dev/tty")
      content
    end

    def initialize_components
      load_tools
      initialize_cli
      initialize_services
      setup_components
    end

    def initialize_cli
      Cli.new(@args)
    end

    def initialize_services
      @client_manager = ClientManager.new(AIA.config)
      @client_manager.initialize_client
    end

    def setup_components
      setup_spinner
      setup_logger
      setup_directives_processor
      setup_prompt
    end

    def load_tools
      Tools.load_tools
    end

    def process_prompt
      @prompt_processor = PromptProcessor.new(
        directives: @directive_output,
        config: AIA.config,
        prompt: @prompt
      )
      @prompt_processor.process
    end

    def handle_output(result)
      ResponseHandler.new(
        result: result
      ).process
    end

    def continue?
      return true unless AIA.config.next.empty? && AIA.config.pipeline.empty?
      false
    end

    def continue_processing(result)
      keep_going(result) unless AIA.config.pipeline.empty?
    end


    def start_chat
      ChatManager.new(
        client: @client_manager.client,
        directives_processor: @directives_processor
      ).start_session
    end

    def log_the_follow_up(the_prompt_text, result)
      logger.info "Follow Up:\n#{the_prompt_text}"
      logger.info "Response:\n#{result}"
    end

    def process_chat_prompt(prompt)
      prompt = preprocess_prompt(prompt)
      if handle_directives(prompt)
        process_directive_output
      else
        process_regular_prompt(prompt)
      end
    end

    def preprocess_prompt(prompt)
      prompt = render_erb(prompt) if AIA.config.erb?
      prompt = render_env(prompt) if AIA.config.shell?
      prompt
    end

    def process_directive_output
      return if @directive_output.empty?
      prompt = preprocess_prompt(@directive_output)
      result = get_and_display_result(prompt)
      log_and_speak(prompt, result)
    end

    def process_regular_prompt(prompt)
      prompt = insert_terse_phrase(prompt)
      result = get_and_display_result(prompt)
      log_and_speak(prompt, result)
    end

    def log_and_speak(prompt, result)
      log_the_follow_up(prompt, result)
      AIA.speak(result)
    end

    def setup_reline_history
      clear_reline_history
    end

    def clear_reline_history
      Reline::HISTORY.clear
    end

    def keep_going(result)
      temp_file = Tempfile.new('aia_pipeline')
      temp_file.write(result)
      temp_file.close

      update_config_for_pipeline(temp_file.path)
      @prompt = Prompt.new.prompt
      call
      puts
    ensure
      temp_file.unlink
    end

    def update_config_for_pipeline(temp_file_path)
      AIA.config.directives = []
      AIA.config.model = ""
      AIA.config.arguments = [AIA.config.pipeline.shift, temp_file_path]
      AIA.config.next = ""
      AIA.config.files = [temp_file_path]
    end

    def handle_directives(prompt)
      signal = PromptManager::Prompt::DIRECTIVE_SIGNAL
      return false unless prompt.start_with?(signal)

      parts = prompt[signal.size..].split(' ')
      directive = parts.shift
      parameters = parts.join(' ')
      AIA.config.directives << [directive, parameters]

      @directive_output = @directives_processor.execute_my_directives
      true
    end

    def insert_terse_phrase(string)
      AIA.config.terse? ? "Be terse in your response. #{string}" : string
    end
  end
end
