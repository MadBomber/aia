# MCP Servers

The Model Context Protocol (MCP) enables tools from different server implementations to be defined in a common consistent way, allowing LLMs that support callback functions (aka tools) to access data that enhances the context of a prompt.

You can find additional MCP servers at https://mcpindex.net

## Overview

This directory contains configuration files for various MCP servers that provide different capabilities to LLMs:

| Server | Purpose | Configuration File |
|--------|---------|--------------------|
| Filesystem | Provides access to the local filesystem | `filesystem.json` |
| iMCP | macOS-specific MCP server for system integration | `imcp.json` |
| Playwright | Enables web automation and scraping capabilities | `playwright_server_definition.json` |

## Configuration Details

### Filesystem Server

The filesystem server allows LLMs to read and interact with the local filesystem:

TODO: fix this JSON file to use a generic directory; maybe $HOME

```json
{
  "type": "stdio",
  "command": [
    "npx",
    "-y",
    "@modelcontextprotocol/server-filesystem",
    "/Users/dewayne/sandbox/git_repos/madbomber/aia/develop"
  ]
}
```

The server is configured to access files within the project's development directory.

### iMCP Server

See: https://github.com/loopwork-ai/iMCP

The iMCP server provides macOS-specific functionality:

```json
{
  "mcpServers" : {
    "iMCP" : {
      "command" : "/Applications/iMCP.app/Contents/MacOS/imcp-server"
    }
  }
}
```

### Playwright Server

The Playwright server enables web automation and browser interaction capabilities:

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

## Usage

These MCP servers can be utilized by LLM applications to extend their capabilities beyond text generation. The configuration files in this directory are used to define how to connect to each server and what capabilities they provide.

## Getting Started

Use the --mcp option with aia to specify which MCP servers to use. You may use the --mcp option multiple times to select more than one server. For example:

```bash
aia prompt_id --mcp filesystem.json --mcp imcp.json --mcp playwright_server_definition.json
# or
aia --chat --mcp filesystem.json --mcp imcp.json --mcp playwright_server_definition.json
# or
aia prompt_id --chat --mcp filesystem.json --mcp imcp.json --mcp playwright_server_definition.json
```

## Additional Resources

- [Model Context Protocol Documentation](https://github.com/anthropics/anthropic-cookbook/tree/main/model_context_protocol)
- [MCP Server Implementation Guidelines](https://modelcontextprotocol.github.io/)
