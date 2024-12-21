# lib/aia/chat_manager.rb


class ChatManager
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
end

