module AIA
  module SetupHelpers
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
  end
end
