# lib/extensions/ruby_llm/provider_fix.rb
#
# Monkey patch to fix LM Studio compatibility with RubyLLM Provider
# LM Studio sometimes returns response.body as a String that fails JSON parsing
# This causes "String does not have #dig method" errors in parse_error

module RubyLLM
  class Provider
    # Override the parse_error method to handle String responses from LM Studio
    def parse_error(response)
      return if response.body.empty?

      body = try_parse_json(response.body)

      # Be more explicit about type checking to prevent String#dig errors
      case body
      when Hash
        # Only call dig if we're certain it's a Hash
        body.dig('error', 'message')
      when Array
        # Only call dig on array elements if they're Hashes
        body.filter_map do |part|
          part.is_a?(Hash) ? part.dig('error', 'message') : part.to_s
        end.join('. ')
      else
        # For Strings or any other type, convert to string
        body.to_s
      end
    rescue StandardError => e
      # Fallback in case anything goes wrong
      "Error parsing response: #{e.message}"
    end
  end
end