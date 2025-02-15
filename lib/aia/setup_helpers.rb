module AIA
  module SetupHelpers
    SPINNER_FORMAT = :classic
    SPINNER_MESSAGE = "composing response ... "

    def setup_spinner
      @spinner = TTY::Spinner.new(":spinner #{SPINNER_MESSAGE}", format: SPINNER_FORMAT)
      @spinner.update(title: SPINNER_MESSAGE)
      @spinner
    end

    def setup_logger
      @logger = AIA::Logging.new(AIA.config.log_file)
      @logger.info(AIA.config.to_h) if AIA.config.debug? || AIA.config.verbose?
      @logger
    end

    def setup_directives_processor
      @directives_processor = AIA::Directives.new
    end

    def setup_prompt
      @prompt = AIA::Prompt.new
      if piped_content && @prompt.prompt
        @prompt.prompt.text = @prompt.prompt.text + piped_content
      end
      @prompt
    end
  end
end
