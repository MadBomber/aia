# lib/aia/directives/checkpoint.rb
#
# Checkpoint and restore directives for managing conversation state.
# Uses RubyLLM's Chat.@messages as the source of truth for conversation history.
#

module AIA
  module Directives
    module Checkpoint
      # Module-level state for checkpoints
      @checkpoints = {}
      @checkpoint_counter = 0
      @last_checkpoint_name = nil

      class << self
        attr_accessor :checkpoints, :checkpoint_counter, :last_checkpoint_name

        # Reset all checkpoint state (useful for testing)
        def reset!
          @checkpoints = {}
          @checkpoint_counter = 0
          @last_checkpoint_name = nil
        end
      end

      # //checkpoint [name]
      # Creates a named checkpoint of the current conversation state.
      # If no name is provided, uses an auto-incrementing number.
      def self.checkpoint(args, _unused = nil)
        name = args.empty? ? nil : args.join(' ').strip

        if name.nil? || name.empty?
          self.checkpoint_counter += 1
          name = checkpoint_counter.to_s
        end

        chats = get_chats
        return "Error: No active chat sessions found." if chats.nil? || chats.empty?

        # Deep copy messages from all chats
        checkpoints[name] = {
          messages: chats.transform_values { |chat|
            chat.messages.map { |msg| deep_copy_message(msg) }
          },
          position: chats.values.first&.messages&.size || 0,
          created_at: Time.now
        }
        self.last_checkpoint_name = name

        puts "Checkpoint '#{name}' created at position #{checkpoints[name][:position]}."
        ""
      end

      # //restore [name]
      # Restores the conversation state to a previously saved checkpoint.
      # If no name is provided, restores to the last checkpoint.
      def self.restore(args, _unused = nil)
        name = args.empty? ? nil : args.join(' ').strip
        name = last_checkpoint_name if name.nil? || name.empty?

        if name.nil?
          return "Error: No checkpoint name provided and no previous checkpoint exists."
        end

        unless checkpoints.key?(name)
          available = checkpoint_names.empty? ? "none" : checkpoint_names.join(', ')
          return "Error: Checkpoint '#{name}' not found. Available: #{available}"
        end

        checkpoint_data = checkpoints[name]
        chats = get_chats

        return "Error: No active chat sessions found." if chats.nil? || chats.empty?

        # Restore messages to each chat
        checkpoint_data[:messages].each do |model_id, saved_messages|
          chat = chats[model_id]
          next unless chat

          # Replace the chat's messages with the saved ones
          restored_messages = saved_messages.map { |msg| deep_copy_message(msg) }
          chat.instance_variable_set(:@messages, restored_messages)
        end

        "Context restored to checkpoint '#{name}' (position #{checkpoint_data[:position]})."
      end

      # //clear
      # Clears the conversation context, optionally keeping the system prompt.
      def self.clear(args, _unused = nil)
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

        # Clear all checkpoints
        checkpoints.clear
        self.checkpoint_counter = 0
        self.last_checkpoint_name = nil

        "Chat context cleared."
      end

      # //review
      # Displays the current conversation context with checkpoint markers.
      def self.review(args, _unused = nil)
        chats = get_chats
        return "Error: No active chat sessions found." if chats.nil? || chats.empty?

        # For multi-model, show first chat's messages (they should be similar for user messages)
        first_chat = chats.values.first
        messages = first_chat&.messages || []

        puts "\n=== Chat Context (RubyLLM) ==="
        puts "Total messages: #{messages.size}"
        puts "Models: #{chats.keys.join(', ')}"
        puts "Checkpoints: #{checkpoint_names.join(', ')}" if checkpoint_names.any?
        puts

        positions = checkpoint_positions

        messages.each_with_index do |msg, index|
          # Show checkpoint marker if one exists at this position
          if positions[index]
            puts "📍 [Checkpoint: #{positions[index].join(', ')}]"
            puts "-" * 40
          end

          role = msg.role.to_s.capitalize
          content = format_message_content(msg)

          puts "#{index + 1}. [#{role}]: #{content}"
          puts
        end

        # Check for checkpoint at the end
        if positions[messages.size]
          puts "📍 [Checkpoint: #{positions[messages.size].join(', ')}]"
          puts "-" * 40
        end

        puts "=== End of Context ==="
        ""
      end

      # //checkpoints
      # Lists all available checkpoints with their details.
      def self.checkpoints_list(args, _unused = nil)
        if checkpoints.empty?
          puts "No checkpoints available."
          return ""
        end

        puts "\n=== Available Checkpoints ==="
        checkpoints.each do |name, data|
          created = data[:created_at]&.strftime('%H:%M:%S') || 'unknown'
          puts "  #{name}: position #{data[:position]}, created #{created}"
        end
        puts "=== End of Checkpoints ==="
        ""
      end

      # Helper methods
      def self.checkpoint_names
        checkpoints.keys
      end

      def self.checkpoint_positions
        positions = {}
        checkpoints.each do |name, data|
          pos = data[:position]
          positions[pos] ||= []
          positions[pos] << name
        end
        positions
      end

      private

      def self.get_chats
        return nil unless AIA.client.respond_to?(:chats)

        AIA.client.chats
      end

      def self.deep_copy_message(msg)
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

      def self.format_message_content(msg)
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

      # Aliases
      class << self
        alias_method :ckp, :checkpoint
        alias_method :cp, :checkpoint
        alias_method :context, :review
        alias_method :checkpoints, :checkpoints_list
      end
    end
  end
end
