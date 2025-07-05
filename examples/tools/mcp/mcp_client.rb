# shared_tools/ruby_llm/mcp/mcp_client.rb
# Base class for MCP client wrappers

require "ruby_llm"
require "ruby_llm/mcp"

class McpClient
  class << self
    attr_accessor :client
  end

  def self.connect
    @client ||= create_client
  end

  def self.disconnect
    @client&.disconnect if @client&.respond_to?(:disconnect)
    @client = nil
  end

  def self.connected?
    !@client.nil?
  end

  private

  def self.create_client
    raise NotImplementedError, "Subclasses must implement create_client method"
  end
end
