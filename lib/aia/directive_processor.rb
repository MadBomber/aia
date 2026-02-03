# lib/aia/directive_processor.rb

require 'faraday'
require 'word_wrapper'
require_relative 'directives/registry'

module AIA
  class DirectiveProcessor
    # Chat-time directive prefix (single slash).
    # File paths like /Users/... are rejected because the first word
    # after the prefix won't match any registered PM directive name.
    DIRECTIVE_PREFIX = '/'

    def initialize
      @prefix_size = DIRECTIVE_PREFIX.size
    end


    # Checks whether a string looks like a chat-time directive.
    # Uses PM.directives as the source of truth for known directive names.
    def directive?(string)
      content = extract_content(string)
      stripped = content.strip

      return false unless stripped.start_with?(DIRECTIVE_PREFIX)

      # Extract the directive name and check it's registered
      sans_prefix = stripped[@prefix_size..]
      method_name = sans_prefix.split(' ').first&.downcase
      return false if method_name.nil? || method_name.empty?

      PM.directives.key?(method_name.to_sym)
    end


    # Process a chat-time directive by dispatching through PM.directives.
    # Returns the block's return value: non-blank string for content directives,
    # nil for operational directives.
    def process(string, _context_manager = nil)
      return string unless directive?(string)

      content = extract_content(string)
      key = content.strip
      sans_prefix = key[@prefix_size..]
      args = sans_prefix.split(' ')
      method_name = args.shift.downcase

      block = PM.directives[method_name.to_sym]
      return "Error: Unknown directive '#{method_name}'" unless block

      # Call with nil context (chat mode, not ERB rendering)
      block.call(nil, *args)
    end


    private

    def extract_content(string)
      if string.is_a?(RubyLLM::Message)
        begin
          string.content
        rescue StandardError
          string.to_s
        end
      else
        string.to_s
      end
    end
  end
end
