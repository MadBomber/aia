# lib/aia/errors.rb

module AIA
  # Base error class for all AIA errors
  class Error < StandardError; end

  # Raised for configuration validation failures
  class ConfigurationError < Error; end

  # Raised for prompt loading, parsing, or processing failures
  class PromptError < Error; end

  # Raised for RubyLLM::Tool loading or execution failures
  class ToolError < Error; end

  # Raised for MCP server connection or communication failures
  class MCPError < Error; end

  # Raised for LLM adapter failures (model setup, chat execution)
  class AdapterError < Error; end

  # Raised for directive parsing or execution failures
  class DirectiveError < Error; end
end
