# MCP Servers

The Model Context Protocol (MCP) enables tools from different server implementations to be defined in a common consistent way, allowing LLMs that support callback functions (aka tools) to access data that enhances the context of a prompt.

You can find additional MCP servers in the [MCP servers repository](https://github.com/modelcontextprotocol/servers).

## Overview

This directory contains sample configuration files for MCP servers that provide different capabilities to LLMs:

| Server | Purpose | Configuration File |
|--------|---------|--------------------|
| Filesystem | Read and work with files under the current directory | `filesystem.json` |
| Apple MCP | macOS apps (Notes, Calendar, Contacts, Mail and more) | `apple-mcp.json` |
| MCP Server Chart | Generate charts and visualizations | `mcp_server_chart.json` |
| Playwright (Microsoft) | Browser automation, started on demand with `npx` | `playwright_one.json` |
| Playwright (ExecuteAutomation) | Browser automation, alternative implementation | `playwright_two.json` |
| Playwright (running server) | Connect to a Playwright MCP server already listening on port 8931 | `playwright_server_definition.json` |
| Tavily | Web search through Tavily's remote MCP server (needs `TAVILY_API_KEY`) | `tavily_mcp_server.json` |

Most of these start their server with `npx`, so Node.js must be installed.

## Configuration Details

### Filesystem Server

See: https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem

The filesystem server allows LLMs to read and interact with the local filesystem. It is limited to the directory given as its last argument; the sample uses `.`, the directory you run `aia` from. Change it to any directory you want to expose.

```json
{
  "type": "stdio",
  "command": [
    "npx",
    "-y",
    "@modelcontextprotocol/server-filesystem",
    "."
  ]
}
```

### Apple MCP Server

See: https://github.com/supermemoryai/apple-mcp

macOS only. Gives access to Apple apps such as Notes, Calendar, Contacts, Messages and Mail.

```json
{
  "mcpServers": {
    "apple-mcp": {
      "command": "npx",
      "args": ["-y", "apple-mcp"]
    }
  }
}
```

### MCP Server Chart

See: https://github.com/antvis/mcp-server-chart

Generates charts from data supplied by the LLM.

```json
{
  "mcpServers": {
    "mcp-server-chart": {
      "command": "npx",
      "args": ["-y", "@antv/mcp-server-chart"]
    }
  }
}
```

### Playwright Servers

Three ways to give the LLM a browser:

- `playwright_one.json` starts Microsoft's server (https://github.com/microsoft/playwright-mcp) with `npx @playwright/mcp`.
- `playwright_two.json` starts the ExecuteAutomation server (https://github.com/executeautomation/mcp-playwright) with `npx @executeautomation/playwright-mcp-server`.
- `playwright_server_definition.json` connects to a Playwright MCP server you have already started on port 8931:

```json
{
  "mcpServers": {
    "playwright": {
      "url": "http://localhost:8931/sse",
      "headers": {},
      "comment": "Local Playwright MCP Server running on port 8931"
    }
  }
}
```

All three name their server `playwright`, so load only one of them at a time.

### Tavily Server

See: https://docs.tavily.com/documentation/mcp

Web search through Tavily's hosted MCP server, reached with `mcp-remote`. Export `TAVILY_API_KEY` before using it.

```json
{
  "mcpServers": {
    "tavily-remote-mcp": {
      "command": "npx -y mcp-remote https://mcp.tavily.com/mcp/?tavilyApiKey=$TAVILY_API_KEY",
      "env": {}
    }
  }
}
```

## Usage

These MCP servers can be utilized by LLM applications to extend their capabilities beyond text generation. The configuration files in this directory are used to define how to connect to each server and what capabilities they provide.

## Getting Started

Use the --mcp option with aia to specify which MCP servers to use. You may use the --mcp option multiple times to select more than one server. For example:

```bash
aia prompt_id --mcp filesystem.json --mcp mcp_server_chart.json --mcp playwright_one.json
# or
aia --chat --mcp filesystem.json --mcp mcp_server_chart.json --mcp playwright_one.json
# or
aia prompt_id --chat --mcp filesystem.json --mcp mcp_server_chart.json --mcp playwright_one.json
```

## Filtering Servers

You can control which servers are connected using `--mcp-use` (whitelist) and `--mcp-skip` (blacklist):

```bash
# Only connect to the filesystem server
aia --chat --mcp filesystem.json --mcp mcp_server_chart.json --mcp-use filesystem

# Connect to all servers except playwright
aia --chat --mcp filesystem.json --mcp playwright_one.json --mcp-skip playwright

# List configured servers without connecting
aia --mcp filesystem.json --mcp mcp_server_chart.json --mcp-list
```

Precedence order:
1. `--no-mcp` disables all MCP (highest priority)
2. `--mcp-use` connects only to named servers
3. `--mcp-skip` connects to all except named servers

## Additional Resources

- [Model Context Protocol Documentation](https://modelcontextprotocol.io)
- [MCP Specification](https://modelcontextprotocol.io/specification)
- [MCP Servers Repository](https://github.com/modelcontextprotocol/servers)
