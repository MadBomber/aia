# lib/aia/main.rb

module AIA ; end

require_relative 'config'
require_relative 'cli'
require_relative 'directives'
require_relative 'dynamic_content'
require_relative 'prompt'
require_relative 'logging'
require_relative 'tools'
require_relative 'user_query'

# Everything is being handled within the context
# of a single class.

class AIA::Main
  SPINNER_FORMAT = :bouncing_ball

  include AIA::DynamicContent
  include AIA::UserQuery
  
  attr_accessor :logger, :tools, :backend, :directive_output

  attr_reader :spinner

  def initialize(args= ARGV)
    @directive_output = ""
    AIA::Tools.load_tools

    AIA::Cli.new(args)

    if AIA.config.debug?
      debug_me('== CONFIG AFTER CLI =='){[
        "AIA.config"
      ]}
    end

    @spinner  = TTY::Spinner.new(":spinner :title", format: SPINNER_FORMAT)
    spinner.update(title: "composing response ... ")

    @logger = AIA::Logging.new(AIA.config.log_file)

    @logger.info(AIA.config) if AIA.config.debug? || AIA.config.verbose?


    @directives_processor = AIA::Directives.new 

    @prompt = AIA::Prompt.new.prompt

    # TODO: still should verify that the tools are ion the $PATH
    # tools.class.verify_tools
  end


  # Function to setup the Reline history with a maximum depth
  def setup_reline_history(max_history_size=5)
    Reline::HISTORY.clear
    # Reline::HISTORY.max_size = max_history_size
  end


  # This will be recursive with the new options
  # --next and --pipeline
  def call
    directive_output = @directives_processor.execute_my_directives

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

    the_prompt.prepend(directive_output + "\n") unless directive_output.nil? || directive_output.empty?

    if AIA.config.terse?
      the_prompt.prepend "Be terse in your response. "
    end

    @backend  = backend_klass.new(
                  text:           the_prompt,
                  files:          AIA.config.arguments    # FIXME: want validated context files
                )

    result = get_and_display_result(the_prompt)

    logger.prompt_result(@prompt, result)

    if AIA.config.chat?
      setup_reline_history
      AIA.speak result
      lets_chat 
    end

    return if AIA.config.next.empty? && AIA.config.pipeline.empty?

    # Reset some config items to defaults
    AIA.config.directives = []
    AIA.config.next       = AIA.config.pipeline.shift
    AIA.config.arguments  = [AIA.config.next, AIA.config.out_file.to_s]
    AIA.config.next       = ""

    @prompt = AIA::Prompt.new.prompt
    call # Recurse!
  end


  def get_and_display_result(the_prompt_text)
    spinner.auto_spin if AIA.config.verbose?

    backend.text  = the_prompt_text
    result        = backend.run

    if AIA.config.verbose?
      spinner.success "Done." 
    end

    AIA.config.out_file.write "\nResponse:\n"

    if STDOUT == AIA.config.out_file
      if AIA.config.render?
        AIA::Glow.new(content: result).run
      else
        result  = result.wrap(indent: 2)
        AIA.config.out_file.write result
      end
    else
      AIA.config.out_file.write result
      if AIA.config.render?
        AIA::Glow.new(file_path: AIA.config.out_file).run
      end
    end

    result
  end


  def log_the_follow_up(the_prompt_text, result)
    logger.info "Follow Up:\n#{the_prompt_text}"
    logger.info "Response:\n#{result}"
  end


  def add_continue_option
    if 'mods' == AIA.config.backend
      continue_option   = " -C"
      AIA.config.extra += continue_option unless AIA.config.extra.include?(continue_option)
    end
  end


  def insert_terse_phrase(a_string)
    if AIA.config.terse?
      a_string.prepend "Be terse in your response. "
    end

    a_string
  end

  
  def handle_directives(the_prompt_text)
    signal = PromptManager::Prompt::DIRECTIVE_SIGNAL
    result = the_prompt_text.start_with?(signal)

    if result
      parts       = the_prompt_text[signal.size..].split(' ')
      directive   = parts.shift
      parameters  = parts.join(' ')
      AIA.config.directives << [directive, parameters]
      directive_output = @directives_processor.execute_my_directives
    else
      directive_output = ""
    end

    result
  end


  def lets_chat
    add_continue_option    

    the_prompt_text = ask_question_with_reline("\nFollow Up: ")

    until the_prompt_text.empty?
      the_prompt_text   = render_erb(the_prompt_text) if AIA.config.erb?
      the_prompt_text   = render_env(the_prompt_text) if AIA.config.shell?

      if handle_directives(the_prompt_text)
        unless directive_output.nil?
          the_prompt_text = insert_terse_phrase(the_prompt_text)
          the_prompt_text << directive_output 
          result          = get_and_display_result(the_prompt_text)

          log_the_follow_up(the_prompt_text, result)
          AIA.speak result
        end
      else
        the_prompt_text = insert_terse_phrase(the_prompt_text)
        result          = get_and_display_result(the_prompt_text)

        log_the_follow_up(the_prompt_text, result)
        AIA.speak result
      end

      the_prompt_text = ask_question_with_reline("\nFollow Up: ")
    end
  end
end
