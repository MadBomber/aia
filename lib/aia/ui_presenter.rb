# lib/aia/ui_presenter.rb
#
# This file contains the UIPresenter class for handling user interface presentation.

require 'tty-screen'
require 'reline'

module AIA
  # The UIPresenter class is responsible for handling all user interface aspects
  # of the AIA application, including displaying messages, formatting responses,
  # and collecting user input.
  class UIPresenter
    # The prompt used when asking for user input in chat mode
    USER_PROMPT = "Follow up (cntl-D or 'exit' to end) #=> "

    # Initializes a new UIPresenter with the given configuration.
    #
    # @param config [OpenStruct] the configuration object
    def initialize(config)
      @config = config
      @terminal_width = TTY::Screen.width
    end

    # Displays the chat session header.
    def display_chat_header
      puts "#{'═' * @terminal_width}\n"
    end

    # Displays a thinking animation while processing.
    def display_thinking_animation
      puts "\n⏳ Processing...\n"
    end

    # Displays the AI response with formatting.
    #
    # @param response [String] the response to display
    def display_ai_response(response)
      puts "\nAI: "
      format_chat_response(response)

      if @config.out_file
        File.open(@config.out_file, 'a') do |file|
          file.puts "\nAI: "
          format_chat_response(response, file)
        end
      end
    end

    # Formats the chat response for better readability, handling code blocks
    # and regular text.
    #
    # @param response [String] the response to format
    # @param output [IO] the output to write to (defaults to $stdout)
    def format_chat_response(response, output = $stdout)
      indent = '   '

      # Handle code blocks specially
      in_code_block = false
      language = ''

      response.each_line do |line|
        line = line.chomp

        # Check for code block delimiters
        if line.match?(/^```(\w*)$/) && !in_code_block
          in_code_block = true
          language = $1
          output.puts "#{indent}```#{language}"
        elsif line.match?(/^```$/) && in_code_block
          in_code_block = false
          output.puts "#{indent}```"
        elsif in_code_block
          # Print code with special formatting
          output.puts "#{indent}#{line}"
        else
          # Handle regular text
          output.puts "#{indent}#{line}"
        end
      end
    end

    # Displays a separator line in the chat session.
    def display_separator
      puts "\n#{'─' * @terminal_width}"
    end

    # Displays the end of the chat session message.
    def display_chat_end
      puts "\nChat session ended."
    end

    # Prompts the user for input and returns the entered text.
    #
    # @return [String, nil] the user input or nil if the session is interrupted
    def ask_question
      puts USER_PROMPT
      $stdout.flush  # Ensure the prompt is displayed immediately
      begin
        input = Reline.readline('', true)
        return nil if input.nil? # Handle Ctrl+D
        Reline::HISTORY << input unless input.strip.empty?
        input
      rescue Interrupt
        puts "\nChat session interrupted."
        return 'exit'
      end
    end

    # Displays a spinner while executing a block of code
    # 
    # @param message [String] the message to display
    # @param operation_type [Symbol] optional operation type to include in message
    # @yield the block to execute while showing the spinner
    # @return [Object] the result of the block
    def with_spinner(message = "Processing", operation_type = nil)
      if @config.verbose
        spinner_message = operation_type ? "#{message} #{operation_type}..." : "#{message}..."
        spinner = TTY::Spinner.new("[:spinner] #{spinner_message}", format: :bouncing_ball)
        spinner.auto_spin

        result = yield

        spinner.stop
        result
      else
        yield
      end
    end
  end
end
