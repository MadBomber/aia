# aia/lia/aia/user_query.rb

require 'reline'

module AIA::UserQuery

  # Function to prompt the user with a question using reline
  def ask_question_with_reline(prompt)
    if prompt.start_with?("\n")
      puts
      puts
      prompt = prompt[1..]
    end

    answer = Reline.readline(prompt)
    Reline::HISTORY.push(answer) unless answer.nil? || Reline::HISTORY.to_a.include?(answer)
    answer
  rescue Interrupt
    ''
  end
end
