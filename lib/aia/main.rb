# lib/aia/main.rb

module AIA ; end

require_relative 'config'
require_relative 'cli'
require_relative 'directives'
require_relative 'prompt'
require_relative 'logging'
require_relative 'tools'

# Everything is being handled within the context
# of a single class.

class AIA::Main

  attr_accessor :logger, :tools, :backend

  def initialize(args= ARGV)    
    AIA::Tools.load_tools

    AIA::Cli.new(args)

    if AIA.config.debug?
      debug_me('== CONFIG AFTER CLI =='){[
        "AIA.config"
      ]}
    end

    @logger = AIA::Logging.new(AIA.config.log_file)

    @logger.info(AIA.config) if AIA.config.debug? || AIA.config.verbose?

    @prompt = AIA::Prompt.new.prompt

    @engine = AIA::Directives.new(prompt: @prompt)

    # TODO: still should verify that the tools are ion the $PATH
    # tools.class.verify_tools
  end


  def speak(what)
    return unless AIA.config.speak?
    # MacOS uses the say command
    system "say #{Shellwords.escape(what)}"
  end


  # Function to setup the Reline history with a maximum depth
  def setup_reline_history(max_history_size=5)
    Reline::HISTORY.clear
    # Reline::HISTORY.max_size = max_history_size
  end


  # Function to prompt the user with a question using reline
  def ask_question_with_reline(prompt)
    answer = Reline.readline(prompt)
    Reline::HISTORY.push(answer) unless answer.nil? || Reline::HISTORY.to_a.include?(answer)
    answer
    rescue Interrupt
      ''
  end


  def call
    @engine.execute_my_directives

    if AIA.config.chat?
      AIA.config.out_file = STDOUT 
      AIA.config.extra = "--quiet" if 'mods' == AIA.config.backend
    end

    # TODO: the context_files left in the @arguments array
    #       should be verified BEFORE asking the user for a
    #       prompt keyword or process the prompt.  Do not
    #       want invalid files to make it this far.

    found = AIA::Tools
              .search_for(
                name: AIA.config.backend, 
                role: :backend
              )

    if found.empty?
      abort "There are no :backend tools named #{AIA.config.backend}"
    end

    if found.size > 1
      abort "There are #{found.size} :backend tools with the name #{AIAA.config.backend}"
    end

    backend_klass = found.first.klass

    abort "backend not found: #{AIA.config.backend}" if backend_klass.nil?

    the_prompt = @prompt.to_s

    if AIA.config.terse?
      the_prompt.prepend "Be terse in your response. "
    end

    @backend  = backend_klass.new(
                  text:           the_prompt,
                  files:          AIA.config.arguments    # FIXME: want validated context files
                )


    result  = backend.run

    AIA.config.out_file.write result

    logger.prompt_result(@prompt, result)


    if AIA.config.chat?
      setup_reline_history
      speak result
      lets_chat 
    end
  end


  def lets_chat
    if 'mods' == AIA.config.backend
      AIA.config.extra += " -C"
    end
    
    backend.text = ask_question_with_reline("\nFollow Up: ")
    
    until backend.text.empty?
      if AIA.config.terse?
        backend.text.prepend "Be terse in your response. "
      end
      
      logger.info "Follow Up: #{backend.text}"
      response = backend.run
      
      speak response

      puts "\nResponse: #{response}"
      logger.info "Response: #{backend.run}"
  
      # TODO: Allow user to enter a directive; loop
      #       until answer is not a directive
      #
      # while !directive do
      backend.text = ask_question_with_reline("\nFollow Up: ")
      
      speak backend.text

      # execute the directive
      # end
    end
  end
end
