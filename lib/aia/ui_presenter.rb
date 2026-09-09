# lib/aia/ui_presenter.rb

require 'tty-screen'
require 'tty-spinner'
require 'tty-table'
require 'reline'
require 'fileutils'

module AIA
  # :reek:TooManyMethods -- one small builder per table/report section keeps each display testable in isolation
  class UIPresenter
    USER_PROMPT = "Follow up (cntl-D or 'exit' to end) #=> ".freeze
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
    end

    # :reek:TooManyStatements -- line-by-line rendering with a code-fence state machine; the states share locals
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
        'exit'
      end
    end

    # Load persistent chat history into Reline
    def load_chat_history
      Reline::HISTORY.clear
      history_file = chat_history_file
      return unless history_file && File.exist?(history_file)

      lines = File.readlines(history_file, chomp: true).last(MAX_HISTORY)
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

    # :reek:TooManyStatements -- one metrics table with header/row/alignment variants for cost vs no-cost display
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
          header = %w[Model Input Output Total Cost x1000 Time]
          row    = [
            model_id,
            input_tokens, output_tokens, total_tokens,
            "$#{'%.5f' % cost_data[:total_cost]}",
            "$#{'%.2f' % (cost_data[:total_cost] * 1000)}",
            time_str
          ]
          alignments = %i[left right right right right right right]
        else
          header = %w[Model Input Output Total Cost Time]
          row    = [model_id, input_tokens, output_tokens, total_tokens, "N/A", time_str]
          alignments = %i[left right right right right right]
        end
      else
        header = %w[Model Input Output Total Time]
        row    = [model_id, input_tokens, output_tokens, total_tokens, time_str]
        alignments = %i[left right right right right]
      end

      table = TTY::Table.new(header, [row])
      rendered = table.render(:unicode, resize: true, alignments: alignments, padding: [0, 1])

      puts rendered
      write_to_output_file(rendered)
    end

    # :reek:TooManyStatements -- table assembly: rows, totals, render, output; each piece delegated to a builder
    def display_multi_model_metrics(metrics_list)
      return unless metrics_list && !metrics_list.empty?

      show_cost       = AIA.config.flags.cost
      show_similarity = metrics_list.any? { |m| m.key?(:similarity) }
      totals          = MultiModelTotals.new(0, 0, 0.0, 0.0)

      rows = metrics_list.map { |metrics| multi_model_row(metrics, totals, show_cost, show_similarity) }
      rows << :separator
      rows << multi_model_totals_row(totals, show_cost, show_similarity)

      table = TTY::Table.new(multi_model_header(show_cost, show_similarity), rows)
      rendered = table.render(:unicode, resize: true,
                                        alignments: multi_model_alignments(show_cost, show_similarity),
                                        padding: [0, 1])

      puts "\nMulti-Model Token Usage"
      puts rendered
      write_to_output_file("Multi-Model Token Usage\n#{rendered}")
    end

    private

    # Running totals accumulated while building multi-model table rows.
    MultiModelTotals = Struct.new(:input, :output, :cost, :max_elapsed)

    def multi_model_header(show_cost, show_similarity)
      header = %w[Model Input Output Total]
      header += %w[Cost x1000] if show_cost
      header << "Time"
      header << "Sim" if show_similarity
      header
    end

    def multi_model_row(metrics, totals, show_cost, show_similarity)
      input_tokens  = metrics[:input_tokens] || 0
      output_tokens = metrics[:output_tokens] || 0
      elapsed       = metrics[:elapsed]

      totals.input       += input_tokens
      totals.output      += output_tokens
      totals.max_elapsed  = [totals.max_elapsed, elapsed || 0].max

      row = [(metrics[:model_id] || metrics[:display_name]).to_s,
             input_tokens, output_tokens, input_tokens + output_tokens]
      row += multi_model_cost_cells(metrics, totals) if show_cost
      row << format_elapsed(elapsed)
      row << format_similarity(metrics[:similarity]) if show_similarity
      row
    end

    # Cost cells for one row; adds to totals only when pricing is available.
    def multi_model_cost_cells(metrics, totals)
      cost_data = calculate_cost(metrics)
      return %w[N/A N/A] unless cost_data[:available]

      cost = cost_data[:total_cost]
      totals.cost += cost
      format_cost_cells(cost)
    end

    def format_cost_cells(cost)
      ["$#{'%.5f' % cost}", "$#{'%.2f' % (cost * 1000)}"]
    end

    def multi_model_totals_row(totals, show_cost, show_similarity)
      row = ["TOTAL", totals.input, totals.output, totals.input + totals.output]
      row += totals.cost.positive? ? format_cost_cells(totals.cost) : ["", ""] if show_cost
      row << format_elapsed(totals.max_elapsed)
      row << "" if show_similarity
      row
    end

    def multi_model_alignments(show_cost, show_similarity)
      alignments = %i[left right right right]
      alignments += %i[right right] if show_cost
      alignments << :right
      alignments << :right if show_similarity
      alignments
    end

    def save_chat_history
      history_file = chat_history_file
      return unless history_file
      dir = File.dirname(history_file)
      FileUtils.mkdir_p(dir)

      entries = Reline::HISTORY.to_a.last(MAX_HISTORY)
      File.write(history_file, entries.join("\n") + "\n")
    end

    def chat_history_file
      config = AIA.config
      if config.respond_to?(:output) && config.output.respond_to?(:history_file)
        hf = config.output.history_file
        return nil if hf == false   # --no-history-file disables chat history
        return File.expand_path(hf) if hf
      end
      paths = config.respond_to?(:paths) ? config.paths : nil
      if paths.respond_to?(:aia_dir) && paths.aia_dir
        return File.join(File.expand_path(paths.aia_dir), 'chat_history')
      end
      HISTORY_FILE
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

      CostCalculator.calculate(
        model_id:      metrics[:model_id],
        input_tokens:  metrics[:input_tokens],
        output_tokens: metrics[:output_tokens]
      )
    end
  end
end
