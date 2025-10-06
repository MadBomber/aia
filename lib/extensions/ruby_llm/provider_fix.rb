# lib/extensions/ruby_llm/provider_fix.rb
#
# Monkey patch to fix LM Studio compatibility with RubyLLM
# LM Studio sometimes returns response.body as a String that fails JSON parsing
# This causes "String does not have #dig method" errors in parse_error

# Load RubyLLM first to ensure Provider class exists
require 'ruby_llm'

module RubyLLM
  module ProviderErrorFix
    # Override the parse_error method to handle String responses from LM Studio
    # Parses error response from provider API.
    #
    # Supports two error formats:
    # 1. OpenAI standard: {"error": {"message": "...", "type": "...", "code": "..."}}
    # 2. Simple format: {"error": "error message"}
    #
    # @param response [Faraday::Response] The HTTP response
    # @return [String, nil] The error message or nil if parsing fails
    #
    # @example OpenAI format
    #   response = double(body: '{"error": {"message": "Rate limit exceeded"}}')
    #   parse_error(response) #=> "Rate limit exceeded"
    #
    # @example Simple format (LM Studio, some local providers)
    #   response = double(body: '{"error": "Token limit exceeded"}')
    #   parse_error(response) #=> "Token limit exceeded"
    def parse_error(response)
      return if response.body.empty?

      body = try_parse_json(response.body)
      case body
      when Hash
        # Handle both formats:
        # - {"error": "message"}          (LM Studio, some providers)
        # - {"error": {"message": "..."}} (OpenAI standard)
        error_value = body['error']
        return nil unless error_value

        case error_value
        when Hash
          error_value['message']
        when String
          error_value
        else
          error_value.to_s if error_value
        end
      when Array
        body.filter_map do |part|
          next unless part.is_a?(Hash)

          error_value = part['error']
          next unless error_value

          case error_value
          when Hash then error_value['message']
          when String then error_value
          else error_value.to_s if error_value
          end
        end.join('. ')
      else
        body.to_s
      end
    rescue StandardError => e
      RubyLLM.logger.debug "Error parsing response: #{e.message}"
      nil
    end
  end
end

# Apply the prepend to all Provider subclasses
# LM Studio uses the OpenAI provider, so we need to prepend to all provider classes
RubyLLM::Provider.prepend(RubyLLM::ProviderErrorFix)

# Also prepend to all registered provider classes
RubyLLM::Provider.providers.each do |slug, provider_class|
  provider_class.prepend(RubyLLM::ProviderErrorFix)
end
