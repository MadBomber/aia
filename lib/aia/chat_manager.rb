# lib/aia/chat_manager.rb


class AIA::ChatManager
  def initialize(client:, directives_processor:)
    @client = client
    @directives_processor = directives_processor
    @spinner = TTY::Spinner.new(":spinner :title", format: :classic)
    @spinner.update(title: "composing response ... ")
  end

  def start_session
    setup_reline_history
    handle_chat_loop
  end

  private

  def handle_chat_loop
    loop do
      prompt = get_user_input
      break if prompt.empty?
      process_chat_interaction(prompt)
    end
  end

  def get_user_input
    ask_question_with_reline("\nFollow Up: ")
  end

  def process_chat_interaction(prompt)
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

  def get_and_display_result(prompt_text)
    @spinner.auto_spin if AIA.config.verbose?
    result = @client.chat(prompt_text)
    @spinner.success("Done.") if AIA.config.verbose?
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
    AIA::Glow.new(content: content).run
  end

  def write_wrapped(content)
    AIA.config.out_file.write(content.wrap(indent: 2))
  end

  def write_to_file(content)
    AIA.config.out_file.write(content)
    render_glow(AIA.config.out_file) if AIA.config.render?
  end

  def log_and_speak(prompt, result)
    log_chat_interaction(prompt, result)
    AIA.speak(result) if AIA.config.speak?
  end

  def log_chat_interaction(prompt, result)
    AIA.config.logger.info "Follow Up:\n#{prompt}"
    AIA.config.logger.info "Response:\n#{result}"
  end

  def setup_reline_history
    Reline::HISTORY.clear
  end

  def handle_directives(prompt)
    signal = AIA::Prompt::DIRECTIVE_SIGNAL
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

