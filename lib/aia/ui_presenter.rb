# lib/aia/ui_presenter.rb

require 'tty-screen'
require 'tty-spinner'
require 'tty-table'
require 'reline'
require 'fileutils'

module AIA
  class UIPresenter
    USER_PROMPT = "Follow up (cntl-D or 'exit' to end) #=> "
    HISTORY_FILE = File.join(Dir.home, '.config', 'aia', 'chat_history')
    MAX_HISTORY = 50


    def initialize
      @terminal_width = TTY::Screen.width
    end

    def display_chat_header
      puts "#{'═' * @terminal_width}\n"
    end


    def display_ai_response(response)
      puts "\nAI: "
      format_chat_response(response)

      out_file = AIA.config.output.file
      if out_file && !out_file.nil?
        File.open(out_file, 'a') do |file|
          file.puts "\nAI: "
          format_chat_response(response, file)
        end
      end
    end


    def format_chat_response(response, output = $stdout)
      indent = '   '

      # Convert RubyLLM::Message to string if necessary
      response_text = if defined?(RubyLLM::Message) && response.is_a?(RubyLLM::Message)
                        response.content.to_s
                      elsif response.respond_to?(:reply)
                        response.reply.to_s
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
        save_chat_history unless input.strip.empty?
        input
      rescue Interrupt
        puts "\nChat session interrupted."
        return 'exit'
      end
    end

    # Load persistent chat history into Reline
    def load_chat_history
      Reline::HISTORY.clear
      return unless File.exist?(HISTORY_FILE)

      lines = File.readlines(HISTORY_FILE, chomp: true).last(MAX_HISTORY)
      lines.each { |line| Reline::HISTORY << line }
    end

    def display_info(message)
      $stderr.puts "\n#{message}"
    end

    def display_error(message)
      $stderr.puts "\n❌ ERROR: #{message}\n"
    end

    def display_warning(message)
      $stderr.puts "\n⚠  WARNING: #{message}\n"
    end

    def with_spinner(message = "Processing", operation_type = nil)
      spinner_message = operation_type ? "#{message} #{operation_type}..." : "#{message}..."
      spinner = TTY::Spinner.new("[:spinner] #{spinner_message}", format: :bouncing_ball)
      spinner.auto_spin

      begin
        result = yield
      ensure
        spinner.stop
      end
      result
    end

    def display_token_metrics(metrics)
      return unless metrics

      model_id      = metrics[:model_id] || 'unknown'
      input_tokens  = metrics[:input_tokens] || 0
      output_tokens = metrics[:output_tokens] || 0
      total_tokens  = input_tokens + output_tokens
      time_str      = format_elapsed(metrics[:elapsed])

      if AIA.config.flags.cost
        cost_data = calculate_cost(metrics)
        if cost_data[:available]
          header = ["Model", "Input", "Output", "Total", "Cost", "x1000", "Time"]
          row    = [
            model_id,
            input_tokens, output_tokens, total_tokens,
            "$#{'%.5f' % cost_data[:total_cost]}",
            "$#{'%.2f' % (cost_data[:total_cost] * 1000)}",
            time_str
          ]
          alignments = [:left, :right, :right, :right, :right, :right, :right]
        else
          header = ["Model", "Input", "Output", "Total", "Cost", "Time"]
          row    = [model_id, input_tokens, output_tokens, total_tokens, "N/A", time_str]
          alignments = [:left, :right, :right, :right, :right, :right]
        end
      else
        header = ["Model", "Input", "Output", "Total", "Time"]
        row    = [model_id, input_tokens, output_tokens, total_tokens, time_str]
        alignments = [:left, :right, :right, :right, :right]
      end

      table = TTY::Table.new(header, [row])
      rendered = table.render(:unicode, resize: true, alignments: alignments, padding: [0, 1])

      puts rendered
      write_to_output_file(rendered)
    end

    def display_multi_model_metrics(metrics_list)
      return unless metrics_list && !metrics_list.empty?

      show_cost       = AIA.config.flags.cost
      show_similarity = metrics_list.any? { |m| m.key?(:similarity) }
      total_input     = 0
      total_output    = 0
      total_cost      = 0.0
      max_elapsed     = 0.0

      header = ["Model", "Input", "Output", "Total"]
      header += ["Cost", "x1000"] if show_cost
      header << "Time"
      header << "Sim" if show_similarity

      rows = metrics_list.map do |metrics|
        model_name    = (metrics[:model_id] || metrics[:display_name]).to_s
        input_tokens  = metrics[:input_tokens] || 0
        output_tokens = metrics[:output_tokens] || 0
        total_tokens  = input_tokens + output_tokens
        elapsed       = metrics[:elapsed]
        time_str      = format_elapsed(elapsed)

        total_input  += input_tokens
        total_output += output_tokens
        max_elapsed   = [max_elapsed, elapsed || 0].max

        row = [model_name, input_tokens, output_tokens, total_tokens]

        if show_cost
          cost_data = calculate_cost(metrics)
          if cost_data[:available]
            row << "$#{'%.5f' % cost_data[:total_cost]}"
            row << "$#{'%.2f' % (cost_data[:total_cost] * 1000)}"
            total_cost += cost_data[:total_cost]
          else
            row += ["N/A", "N/A"]
          end
        end

        row << time_str
        row << format_similarity(metrics[:similarity]) if show_similarity
        row
      end

      # Totals row
      all_tokens = total_input + total_output
      total_time = format_elapsed(max_elapsed)
      rows << :separator

      totals = ["TOTAL", total_input, total_output, all_tokens]
      if show_cost && total_cost > 0
        totals << "$#{'%.5f' % total_cost}"
        totals << "$#{'%.2f' % (total_cost * 1000)}"
      elsif show_cost
        totals += ["", ""]
      end
      totals << total_time
      totals << "" if show_similarity
      rows << totals

      alignments = [:left, :right, :right, :right]
      alignments += [:right, :right] if show_cost
      alignments << :right
      alignments << :right if show_similarity

      table = TTY::Table.new(header, rows)
      rendered = table.render(:unicode, resize: true, alignments: alignments, padding: [0, 1])

      puts "\nMulti-Model Token Usage"
      puts rendered
      write_to_output_file("Multi-Model Token Usage\n#{rendered}")
    end

    private

    def save_chat_history
      dir = File.dirname(HISTORY_FILE)
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)

      entries = Reline::HISTORY.to_a.last(MAX_HISTORY)
      File.write(HISTORY_FILE, entries.join("\n") + "\n")
    end

    def format_similarity(score)
      return "ref" if score.nil?
      "%.1f%%" % (score * 100)
    end

    def format_elapsed(seconds)
      return "" unless seconds

      if seconds < 60
        "%.1fs" % seconds
      else
        minutes = (seconds / 60).to_i
        secs = seconds % 60
        "#{minutes}m %04.1fs" % secs
      end
    end

    def write_to_output_file(text)
      out_file = AIA.config.output.file
      return unless out_file

      File.open(out_file, 'a') { |f| f.puts text }
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
