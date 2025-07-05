# shared_tools/ruby_llm/mcp/github_mcp_server.rb
# brew install github_mcp_server

require_relative "mcp_client"

class GithubMcpServer < McpClient
  private

  def self.create_client
    RubyLLM::MCP.client(
      name: "github-mcp-server",
      transport_type: :stdio,
      config: {
        command: "/opt/homebrew/bin/github-mcp-server", # brew install github-mcp-server
        args: %w[stdio],
        env: { "GITHUB_PERSONAL_ACCESS_TOKEN" => ENV.fetch("GITHUB_PERSONAL_ACCESS_TOKEN") },
      },
    )
  end
end

__END__


A GitHub MCP server that handles various tools and resources.

Usage:
  server [command]

Available Commands:
  completion  Generate the autocompletion script for the specified shell
  help        Help about any command
  stdio       Start stdio server

Flags:
      --dynamic-toolsets         Enable dynamic toolsets
      --enable-command-logging   When enabled, the server will log all command requests and responses to the log file
      --export-translations      Save translations to a JSON file
      --gh-host string           Specify the GitHub hostname (for GitHub Enterprise etc.)
  -h, --help                     help for server
      --log-file string          Path to log file
      --read-only                Restrict the server to read-only operations
      --toolsets strings         An optional comma separated list of groups of tools to allow, defaults to enabling all (default [all])
  -v, --version                  version for server

Use "server [command] --help" for more information about a command.
