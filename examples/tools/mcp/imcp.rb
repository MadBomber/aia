# shared_tools/ruby_llm/mcp/imcp.rb
# iMCP is a MacOS program that provides access to notes,calendar,contacts, etc.
# See: https://github.com/loopwork/iMCP
# brew install --cask loopwork/tap/iMCP
#
# CAUTION: AIA is getting an exception when trying to use this MCP client.  Its returning to
#          do a to_sym on a nil value.  This is due to a lack of a nil guard in the
#          version 0.3.1 of the ruby_llm-mpc Parameter#item_type method.
#
# NOTE: iMCP's server is a noisy little thing shooting all its log messages to STDERR.
#       To silence it, redirect STDERR to /dev/null.
#       If you messages then you might want to redirect STDERR to a file.
#

require_relative 'mcp_client'

class Imcp < McpClient
  private

  def self.create_client
    RubyLLM::MCP.client(
      name: "imcp-server",
      transport_type: :stdio,
      config: {
        command: "/Applications/iMCP.app/Contents/MacOS/imcp-server 2> /dev/null"
      }
    )
  end
end
