# shared_tools/ruby_llm/mcp/imcp.rb
# iMCP is a MacOS program that provides access to notes,calendar,contacts, etc.
# See: https://github.com/loopwork/iMCP
# brew install --cask loopwork/tap/iMCP
#

require 'ruby_llm/mcp'

RubyLLM::MCP.add_client(
  name: "imcp-server",
  transport_type: :stdio,
  config: {
    command: "/Applications/iMCP.app/Contents/MacOS/imcp-server 2> /dev/null"
  }
)
