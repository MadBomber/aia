# aia/lib/aia/chat.rb

class AIA::Chat
  attr_accessor :prompt, :backend, :logger, :response

  def initialize(
        prompt:
      )
    @prompt   = prompt
    @backend  = AIA.config.tools.backend
    @logger   = AIA.config.tools.logger
    @engine   = AIA::Directives.new(prompt: prompt)
    @response = ""

    AIA.config.out_file = STDOUT 
    AIA.config.extra = "--quiet" if 'mods' == AIA.config.backend

    Reline::HISTORY.clear
  end


  def run
    process_initial_prompt
    until :done == follow_up do
      process_response
    end
  end


  def process_initial_prompt
    log_prompt
    send_prompt
    process_response
  end


  def log_prompt
    return if logger.nil?
    logger.info prompt.to_s # NOTE: side-effects
  end


  def send_prompt
    backend.text = prompt.to_s
    backend.text.prepend(AIA::Clause::Terse) if AIA.config.terse?
    @response = backend.run
  end


  def follow_up
    answer = ask_question_with_reline("Follow Up: ")
    
    return(:done) if answer.nil? || answer.empty? || %w[q quit exit end done].include?(answer.downcase)

    prompt.text = answer

    log_prompt
    send_prompt

    speak response if AIA.config.speak?
    show_response
    log_response
  end


  def ask_question_with_reline(prompt)
    answer = Reline.readline(prompt)
    Reline::HISTORY.push(answer) unless answer.nil? || Reline::HISTORY.to_a.include?(answer)
    answer
    rescue Interrupt
      ''
  end


  def show_response
    puts <<~EOS

      Response:
      #{response.wrap(indent: 2)}

    EOS
  end
end
