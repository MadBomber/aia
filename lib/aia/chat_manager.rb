# lib/aia/chat_manager.rb


class AIA::ChatManager
  def initialize(client:)
    @client = client
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

