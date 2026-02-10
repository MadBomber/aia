#!/usr/bin/env bash
# examples/20_mcp_servers.sh
#
# Demonstrates MCP (Model Context Protocol) server integration.
# MCP servers expose tools over stdio that the model can call.
#
# AIA supports two ways to configure MCP servers:
#
# 1. JSON file via --mcp (Claude Desktop / VS Code format):
#      {
#        "mcpServers": {
#          "server_name": {
#            "command": "npx",
#            "args": ["-y", "@org/server", "/path"],
#            "env": {},
#            "timeout": 10000
#          }
#        }
#      }
#
# 2. YAML in the AIA config file (aia_config.yml):
#      mcp_servers:
#        - name: server_name
#          command: npx
#          args: ["-y", "@org/server", "/path"]
#          timeout: 10000
#
# Both forms are equivalent. JSON is handy for sharing configs
# with Claude Desktop; YAML keeps everything in one config file.
#
# Filtering:
#   --mcp-use name1,name2    Connect only these servers
#   --mcp-skip name1,name2   Skip these servers
#   --no-mcp                 Disable all MCP servers
#   --mcp-list               List configured servers and exit
#
# Prerequisites:
#   - Run 00_setup_aia.sh first
#   - Node.js / npx installed (for the filesystem MCP server)
# Usage: cd examples && bash 20_mcp_servers.sh

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

MCP_YAML_CONFIG="aia_config_with_mcp.yml"

echo "=== Demo 20: MCP Servers ==="
echo
echo "MCP servers expose tools over stdio that the model can call."
echo "AIA connects to them at startup and registers their tools."
echo

# --- Check that npx is available ---

if ! command -v npx &> /dev/null; then
  echo "ERROR: npx is not installed."
  echo "       Install Node.js from: https://nodejs.org"
  exit 1
fi

echo "The prompt file prompts_dir/list_with_mcp.md contains:"
echo "==="
cat prompts_dir/list_with_mcp.md
echo "==="
echo

# --- Part 1: JSON config via --mcp ---

echo "--- Part 1: JSON config via --mcp ---"
echo
echo "The JSON file mcp/filesystem.json contains:"
echo "==="
cat mcp/filesystem.json
echo "==="
echo
echo "This configures the @modelcontextprotocol/server-filesystem"
echo "MCP server with access to the prompts_dir directory."
echo
echo "Running: aia -c ${CONFIG} --no-output --mcp mcp/filesystem.json list_with_mcp"
echo

aia -c "${CONFIG}" --no-output --mcp mcp/filesystem.json list_with_mcp

echo
echo

# --- Part 2: YAML config in aia_config.yml ---

echo "--- Part 2: YAML config in the AIA config file ---"
echo
echo "The same server can be defined directly in the config file."
echo "The file mcp/aia_config_with_mcp.yml contains:"
echo "==="
cat "${MCP_YAML_CONFIG}"
echo "==="
echo
echo "With the MCP server in the config file, no --mcp flag is needed."
echo
echo "Running: aia -c ${MCP_YAML_CONFIG} --no-output list_with_mcp"
echo

aia -c "${MCP_YAML_CONFIG}" --no-output list_with_mcp
