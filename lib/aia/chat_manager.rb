# lib/aia/chat_manager.rb


class AIA::ChatManager
  def initialize(client:, directives_processor:)
    @client = client
    @directives_processor = directives_processor
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

  def log_chat_interaction(prompt, result)
    AIA.config.logger.info "Follow Up:\n#{prompt}"
    AIA.config.logger.info "Response:\n#{result}"
  end
end

