# lib/aia/directives/context_directives.rb
#
# Checkpoint and restore directives for managing conversation state.
# Uses RubyLLM's Chat.@messages as the source of truth for conversation history.

module AIA
  class ContextDirectives < Directive
    attr_accessor :checkpoint_store, :checkpoint_counter, :last_checkpoint_name

    def initialize
      super
      reset!
    end

    def reset!
      @checkpoint_store     = {}
      @checkpoint_counter   = 0
      @last_checkpoint_name = nil
    end

    desc "Create a named checkpoint of the current context"
    def checkpoint(args, _unused = nil)
      name = args.empty? ? nil : args.join(' ').strip

      if name.nil? || name.empty?
        @checkpoint_counter += 1
        name = @checkpoint_counter.to_s
      end

      chats = get_chats
      return "Error: No active chat sessions found." if chats.nil? || chats.empty?

      first_chat_messages = chats.values.first&.messages || []
      @checkpoint_store[name] = {
        messages: chats.transform_values { |chat|
          chat.messages.map { |msg| deep_copy_message(msg) }
        },
        position: first_chat_messages.size,
        created_at: Time.now,
        topic_preview: extract_last_user_message(first_chat_messages)
      }
      @last_checkpoint_name = name

      puts "Checkpoint '#{name}' created at position #{@checkpoint_store[name][:position]}."
      ""
    end
    alias_method :ckp, :checkpoint
    alias_method :cp,  :checkpoint

    desc "Restore context to a previous checkpoint"
    def restore(args, _unused = nil)
      name = args.empty? ? nil : args.join(' ').strip

      if name.nil? || name.empty?
        name = find_previous_checkpoint
        if name.nil?
          return "Error: No previous checkpoint to restore to."
        end
      end

      unless @checkpoint_store.key?(name)
        available = checkpoint_names.empty? ? "none" : checkpoint_names.join(', ')
        return "Error: Checkpoint '#{name}' not found. Available: #{available}"
      end

      checkpoint_data = @checkpoint_store[name]
      chats = get_chats

      return "Error: No active chat sessions found." if chats.nil? || chats.empty?

      checkpoint_data[:messages].each do |model_id, saved_messages|
        chat = chats[model_id]
        next unless chat

        restored_messages = saved_messages.map { |msg| deep_copy_message(msg) }
        chat.instance_variable_set(:@messages, restored_messages)
      end

      restored_position = checkpoint_data[:position]
      removed_count = remove_invalid_checkpoints(restored_position)

      @last_checkpoint_name = name

      msg = "Context restored to checkpoint '#{name}' (position #{restored_position})."
      msg += " Removed #{removed_count} checkpoint(s) that were beyond this position." if removed_count > 0
      msg
    end

    desc "Clear the conversation context"
    def clear(args, _unused = nil)
      keep_system = !args.include?('--all')

      chats = get_chats
      return "Error: No active chat sessions found." if chats.nil? || chats.empty?

      chats.each do |_model_id, chat|
        if keep_system
          system_msg = chat.messages.find { |m| m.role == :system }
          chat.instance_variable_set(:@messages, [])
          chat.add_message(system_msg) if system_msg
        else
          chat.instance_variable_set(:@messages, [])
        end
      end

      @checkpoint_store.clear
      @checkpoint_counter = 0
      @last_checkpoint_name = nil

      "Chat context cleared."
    end

    desc "Display the current conversation context with checkpoint markers"
    def review(args, _unused = nil)
      chats = get_chats
      return "Error: No active chat sessions found." if chats.nil? || chats.empty?

      first_chat = chats.values.first
      messages = first_chat&.messages || []

      puts "\n=== Chat Context (RubyLLM) ==="
      puts "Total messages: #{messages.size}"
      puts "Models: #{chats.keys.join(', ')}"
      puts "Checkpoints: #{checkpoint_names.join(', ')}" if checkpoint_names.any?
      puts

      positions = checkpoint_positions

      messages.each_with_index do |msg, index|
        if positions[index]
          puts "📍 [Checkpoint: #{positions[index].join(', ')}]"
          puts "-" * 40
        end

        role = msg.role.to_s.capitalize
        content = format_message_content(msg)

        puts "#{index + 1}. [#{role}]: #{content}"
        puts
      end

      if positions[messages.size]
        puts "📍 [Checkpoint: #{positions[messages.size].join(', ')}]"
        puts "-" * 40
      end

      puts "=== End of Context ==="
      ""
    end
    alias_method :context, :review

    desc "List all available checkpoints"
    def checkpoints_list(args, _unused = nil)
      if @checkpoint_store.empty?
        puts "No checkpoints available."
        return ""
      end

      puts "\n=== Available Checkpoints ==="
      @checkpoint_store.each do |name, data|
        created = data[:created_at]&.strftime('%H:%M:%S') || 'unknown'
        puts "  #{name}: position #{data[:position]}, created #{created}"
        if data[:topic_preview] && !data[:topic_preview].empty?
          puts "    → \"#{data[:topic_preview]}\""
        end
      end
      puts "=== End of Checkpoints ==="
      ""
    end
    alias_method :checkpoints, :checkpoints_list

    # --- helpers (no desc → not registered as directives) ---

    def checkpoint_names
      @checkpoint_store.keys
    end

    def checkpoint_positions
      positions = {}
      @checkpoint_store.each do |name, data|
        pos = data[:position]
        positions[pos] ||= []
        positions[pos] << name
      end
      positions
    end

    def remove_invalid_checkpoints(max_position)
      invalid_names = @checkpoint_store.select { |_name, data| data[:position] > max_position }.keys
      invalid_names.each { |name| @checkpoint_store.delete(name) }
      invalid_names.size
    end

    def find_previous_checkpoint
      return nil if @checkpoint_store.size < 2

      sorted = @checkpoint_store.sort_by { |_name, data| -data[:position] }
      sorted[1]&.first
    end

    private

    def get_chats
      return nil unless AIA.client.respond_to?(:chats)
      AIA.client.chats
    end

    def deep_copy_message(msg)
      RubyLLM::Message.new(
        role: msg.role,
        content: msg.content,
        tool_calls: msg.tool_calls&.transform_values { |tc| tc.dup rescue tc },
        tool_call_id: msg.tool_call_id,
        input_tokens: msg.input_tokens,
        output_tokens: msg.output_tokens,
        model_id: msg.model_id
      )
    end

    def format_message_content(msg)
      if msg.tool_call?
        tool_names = msg.tool_calls.values.map(&:name).join(', ')
        "[Tool calls: #{tool_names}]"
      elsif msg.tool_result?
        result_preview = msg.content.to_s[0..50]
        "[Tool result for: #{msg.tool_call_id}] #{result_preview}..."
      else
        content = msg.content.to_s
        content.length > 150 ? "#{content[0..147]}..." : content
      end
    end

    def extract_last_user_message(messages, max_length: 70)
      return "" if messages.nil? || messages.empty?

      last_user_msg = messages.reverse.find { |msg| msg.role == :user }
      return "" unless last_user_msg

      content = last_user_msg.content.to_s.strip
      content = content.gsub(/\s+/, ' ')
      content.length > max_length ? "#{content[0..max_length - 4]}..." : content
    end
  end
end
