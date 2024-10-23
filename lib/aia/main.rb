# lib/aia/main.rb

require_relative 'config'
require_relative 'cli'
require_relative 'client'
require_relative 'directives'
require_relative 'dynamic_content'
require_relative 'prompt'
require_relative 'logging'
require_relative 'tools'
require_relative 'user_query'

module AIA
  class Main
    SPINNER_FORMAT = :bouncing_ball

    include DynamicContent
    include UserQuery
    
    attr_accessor :logger, :tools, :directive_output, :piped_content
    attr_reader :spinner

    def initialize(args = ARGV)
      @piped_content = read_piped_content
      @directive_output = ""
      initialize_components(args)
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

    def initialize_components(args)
      Tools.load_tools
      Cli.new(args)
      AIA.client = AIA::Client.chat
      setup_spinner
      setup_logger
      setup_directives_processor
      setup_prompt
    end

    def setup_spinner
      @spinner = TTY::Spinner.new(":spinner :title", format: SPINNER_FORMAT)
      spinner.update(title: "composing response ... ")
    end

    def setup_logger
      @logger = Logging.new(AIA.config.log_file)
      @logger.info(AIA.config) if AIA.config.debug? || AIA.config.verbose?
    end

    def setup_directives_processor
      @directives_processor = Directives.new
    end

    def setup_prompt
      @prompt = Prompt.new.prompt
      @prompt.text += piped_content if piped_content
    end

    def process_directives
      @directive_output = @directives_processor.execute_my_directives
    end

    def build_prompt
      prompt = @prompt.to_s
      prompt.prepend("#{@directive_output}\n") unless @directive_output&.empty?
      prompt.prepend("Be terse in your response. ") if AIA.config.terse?
      prompt
    end

    def process_prompt
      get_and_display_result(build_prompt)
    end

    def handle_output(result)
      AIA.speak(result) if AIA.config.speak?
      logger.prompt_result(@prompt, result)
      start_chat if AIA.config.chat?
    end

    def continue?
      !AIA.config.next.empty? || !AIA.config.pipeline.empty?
    end

    def continue_processing(result)
      keep_going(result) unless AIA.config.pipeline.empty?
    end

    def get_and_display_result(prompt_text)
      spinner.auto_spin if AIA.config.verbose?
      result = AIA.client.chat(prompt_text)
      spinner.success("Done.") if AIA.config.verbose?
      display_result(result)
      result
    end

    def display_result(result)
      AIA.config.out_file.write("\nResponse:\n")
      if STDOUT == AIA.config.out_file
        AIA.config.render? ? render_glow(result) : write_wrapped(result)
      else
        write_to_file(result)
      end
    end

    def render_glow(content)
      Glow.new(content: content).run
    end

    def write_wrapped(content)
      AIA.config.out_file.write(content.wrap(indent: 2))
    end

    def write_to_file(content)
      AIA.config.out_file.write(content)
      render_glow(AIA.config.out_file) if AIA.config.render?
    end

    def start_chat
      setup_reline_history
      lets_chat
    end

    def lets_chat
      loop do
        prompt = ask_question_with_reline("\nFollow Up: ")
        break if prompt.empty?
        process_chat_prompt(prompt)
      end
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

    def setup_reline_history(max_history_size = 5)
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
