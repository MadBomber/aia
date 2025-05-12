# lib/aia/ui_presenter.rb

require 'tty-screen'
require 'reline'

module AIA
  class UIPresenter
    USER_PROMPT = "Follow up (cntl-D or 'exit' to end) #=> "


    def initialize
      @terminal_width = TTY::Screen.width
    end

    def display_chat_header
      puts "#{'═' * @terminal_width}\n"
    end


    def display_thinking_animation
      puts "\n⏳ Processing...\n"
    end


    def display_ai_response(response)
      puts "\nAI: "
      format_chat_response(response)

      if AIA.config.out_file
        File.open(AIA.config.out_file, 'a') do |file|
          file.puts "\nAI: "
          format_chat_response(response, file)
        end
      end
    end


    def format_chat_response(response, output = $stdout)
      indent = '   '

      # Convert RubyLLM::Message to string if necessary
      response_text = if response.is_a?(RubyLLM::Message)
                        response.content.to_s
                      elsif response.respond_to?(:to_s)
                        response.to_s
                      else
                        response
                      end

      in_code_block = false
      language = ''

      response_text.each_line do |line|
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


    def display_separator
      puts "\n#{'─' * @terminal_width}"
    end


    def display_chat_end
      puts "\nChat session ended."
    end


    # This is the follow up question in a chat session
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

    def display_info(message)
      puts "\n#{message}"
    end

    def with_spinner(message = "Processing", operation_type = nil)
      if AIA.verbose?
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
