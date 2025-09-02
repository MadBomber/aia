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

      if AIA.config.out_file && !AIA.config.out_file.nil?
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
        if (match = line.match(/^```(\w*)$/)) && !in_code_block
          in_code_block = true
          language = match[1]
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

        begin
          result = yield
        ensure
          spinner.stop
        end
        result
      else
        yield
      end
    end

    def display_token_metrics(metrics)
      return unless metrics
      
      output_lines = []
      output_lines << "═" * 55
      output_lines << "Model: #{metrics[:model_id]}"
      
      if AIA.config.show_cost
        output_lines.concat(format_metrics_with_cost(metrics))
      else
        output_lines.concat(format_metrics_basic(metrics))
      end
      
      output_lines << "═" * 55
      
      # Output to STDOUT
      output_lines.each { |line| puts line }
      
      # Also write to file if configured
      if AIA.config.out_file && !AIA.config.out_file.nil?
        File.open(AIA.config.out_file, 'a') do |file|
          output_lines.each { |line| file.puts line }
        end
      end
    end
    
    def display_multi_model_metrics(metrics_list)
      return unless metrics_list && !metrics_list.empty?
      
      output_lines = []
      
      # Determine table width based on whether costs are shown
      if AIA.config.show_cost
        table_width = 80
      else
        table_width = 60
      end
      
      output_lines << "═" * table_width
      output_lines << "Multi-Model Token Usage"
      output_lines << "─" * table_width
      
      # Build header row
      if AIA.config.show_cost
        output_lines << sprintf("%-20s %10s %10s %10s %12s %10s", 
                                "Model", "Input", "Output", "Total", "Cost", "x1000")
        output_lines << "─" * table_width
      else
        output_lines << sprintf("%-20s %10s %10s %10s", 
                                "Model", "Input", "Output", "Total")
        output_lines << "─" * table_width
      end
      
      # Process each model
      total_input = 0
      total_output = 0
      total_cost = 0.0
      
      metrics_list.each do |metrics|
        model_name = metrics[:model_id]
        # Truncate model name if too long
        model_name = model_name[0..17] + ".." if model_name.length > 19
        
        input_tokens = metrics[:input_tokens] || 0
        output_tokens = metrics[:output_tokens] || 0
        total_tokens = input_tokens + output_tokens
        
        if AIA.config.show_cost
          cost_data = calculate_cost(metrics)
          if cost_data[:available]
            cost_str = "$#{'%.5f' % cost_data[:total_cost]}"
            x1000_str = "$#{'%.2f' % (cost_data[:total_cost] * 1000)}"
            total_cost += cost_data[:total_cost]
          else
            cost_str = "N/A"
            x1000_str = "N/A"
          end
          
          output_lines << sprintf("%-20s %10d %10d %10d %12s %10s",
                                  model_name, input_tokens, output_tokens, total_tokens, cost_str, x1000_str)
        else
          output_lines << sprintf("%-20s %10d %10d %10d",
                                  model_name, input_tokens, output_tokens, total_tokens)
        end
        
        total_input += input_tokens
        total_output += output_tokens
      end
      
      # Display totals row
      output_lines << "─" * table_width
      total_tokens = total_input + total_output
      
      if AIA.config.show_cost && total_cost > 0
        cost_str = "$#{'%.5f' % total_cost}"
        x1000_str = "$#{'%.2f' % (total_cost * 1000)}"
        output_lines << sprintf("%-20s %10d %10d %10d %12s %10s",
                               "TOTAL", total_input, total_output, total_tokens, cost_str, x1000_str)
      else
        output_lines << sprintf("%-20s %10d %10d %10d",
                               "TOTAL", total_input, total_output, total_tokens)
      end
      
      output_lines << "═" * table_width
      
      # Output to STDOUT
      output_lines.each { |line| puts line }
      
      # Also write to file if configured
      if AIA.config.out_file && !AIA.config.out_file.nil?
        File.open(AIA.config.out_file, 'a') do |file|
          output_lines.each { |line| file.puts line }
        end
      end
    end
    
    private
    
    def display_metrics_basic(metrics)
      puts "Input tokens:  #{metrics[:input_tokens] || 'N/A'}"
      puts "Output tokens: #{metrics[:output_tokens] || 'N/A'}"
      
      if metrics[:input_tokens] && metrics[:output_tokens]
        total = metrics[:input_tokens] + metrics[:output_tokens]
        puts "Total tokens:  #{total}"
      end
    end
    
    def format_metrics_basic(metrics)
      lines = []
      lines << "Input tokens:  #{metrics[:input_tokens] || 'N/A'}"
      lines << "Output tokens: #{metrics[:output_tokens] || 'N/A'}"
      
      if metrics[:input_tokens] && metrics[:output_tokens]
        total = metrics[:input_tokens] + metrics[:output_tokens]
        lines << "Total tokens:  #{total}"
      end
      
      lines
    end
    
    def display_metrics_with_cost(metrics)
      cost_data = calculate_cost(metrics)
      
      if cost_data[:available]
        puts "Input tokens:  #{metrics[:input_tokens]} ($#{'%.5f' % cost_data[:input_cost]})"
        puts "Output tokens: #{metrics[:output_tokens]} ($#{'%.5f' % cost_data[:output_cost]})"
        puts "Total cost:    $#{'%.5f' % cost_data[:total_cost]}"
        puts "Cost x1000:    $#{'%.2f' % (cost_data[:total_cost] * 1000)}"
      else
        puts "Input tokens:  #{metrics[:input_tokens] || 'N/A'}"
        puts "Output tokens: #{metrics[:output_tokens] || 'N/A'}"
        total = (metrics[:input_tokens] || 0) + (metrics[:output_tokens] || 0)
        puts "Total tokens:  #{total}"
        puts "Cost:          N/A (pricing not available)"
      end
    end
    
    def format_metrics_with_cost(metrics)
      lines = []
      cost_data = calculate_cost(metrics)
      
      if cost_data[:available]
        lines << "Input tokens:  #{metrics[:input_tokens]} ($#{'%.5f' % cost_data[:input_cost]})"
        lines << "Output tokens: #{metrics[:output_tokens]} ($#{'%.5f' % cost_data[:output_cost]})"
        lines << "Total cost:    $#{'%.5f' % cost_data[:total_cost]}"
        lines << "Cost x1000:    $#{'%.2f' % (cost_data[:total_cost] * 1000)}"
      else
        lines << "Input tokens:  #{metrics[:input_tokens] || 'N/A'}"
        lines << "Output tokens: #{metrics[:output_tokens] || 'N/A'}"
        total = (metrics[:input_tokens] || 0) + (metrics[:output_tokens] || 0)
        lines << "Total tokens:  #{total}"
        lines << "Cost:          N/A (pricing not available)"
      end
      
      lines
    end
    
    def calculate_cost(metrics)
      return { available: false } unless metrics[:model_id] && metrics[:input_tokens] && metrics[:output_tokens]
      
      # Look up model info from RubyLLM
      begin
        model_info = RubyLLM::Models.find(metrics[:model_id])
        return { available: false } unless model_info
        
        input_price = model_info.input_price_per_million
        output_price = model_info.output_price_per_million
        
        return { available: false } unless input_price && output_price
        
        input_cost = metrics[:input_tokens] * input_price / 1_000_000.0
        output_cost = metrics[:output_tokens] * output_price / 1_000_000.0
        total_cost = input_cost + output_cost
        
        {
          available: true,
          input_cost: input_cost,
          output_cost: output_cost,
          total_cost: total_cost
        }
      rescue StandardError => e
        { available: false, error: e.message }
      end
    end
  end
end
