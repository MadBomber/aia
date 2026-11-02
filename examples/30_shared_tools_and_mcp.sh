#!/usr/bin/env bash
# examples/30_shared_tools_and_mcp.sh
#
# Demonstrates the whole shared_tools gem in one session: its RubyLLM::Tool
# classes (system, git, code, data, web) and its RubyLLM::MCP server classes
# (memory, sequential thinking, charts, Playwright, GitHub, Tavily, ...).
#
# The config file aia_config_shared_tools.yml does all of the wiring:
#
#   require_libs:
#     - shared_tools          # 80+ RubyLLM::Tool classes
#     - shared_tools/mcp      # 10 RubyLLM::MCP server classes
#   mcp_servers:
#     - SharedTools::MCP::Memory
#     - SharedTools::MCP::GitHub
#     ...
#
# An mcp_servers: entry can name a RubyLLM::MCP subclass. AIA loads the
# require_libs first, then connects each named server. A server that is
# missing its API key reports itself unavailable and is skipped with a note.
#
# Prerequisites:
#   - Run 00_setup_aia.sh first
#   - shared_tools >= 0.7.1 (gem install shared_tools)
#   - Node.js / npx (memory, sequential thinking, chart and Playwright
#     servers are downloaded on first use)
#   - Optional keys: GITHUB_PERSONAL_ACCESS_TOKEN (+ github-mcp-server),
#     TAVILY_API_KEY, BRAVE_API_KEY, NOTION_TOKEN, SLACK_MCP_XOXP_TOKEN,
#     HF_TOKEN. Servers without their key are skipped.
# Usage: cd examples && bash 30_shared_tools_and_mcp.sh

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

ST_CONFIG="aia_config_shared_tools.yml"

echo "=== Demo 30: shared_tools — every tool and MCP server ==="
echo

# --- Prerequisite checks ---

if ! gem list shared_tools --installed --version '>= 0.7.1' > /dev/null 2>&1; then
  echo "ERROR: shared_tools 0.7.1 or newer is not installed."
  echo "       Install with: gem install shared_tools"
  exit 1
fi

if ! command -v npx &> /dev/null; then
  echo "ERROR: npx is not installed."
  echo "       Install Node.js from: https://nodejs.org"
  exit 1
fi

echo "The config file ${ST_CONFIG} contains:"
echo "==="
cat "${ST_CONFIG}"
echo "==="
echo

# --- Part 1: Inventory ---

echo "--- Part 1: What gets loaded ---"
echo
echo "--mcp-list shows which MCP servers will connect. Servers missing"
echo "their API key are skipped with a note."
echo
echo "Running: aia -c ${ST_CONFIG} --mcp-list"
echo

aia -c "${ST_CONFIG}" --mcp-list

echo
echo "--list-tools --mcp-list connects every server and lists every tool."
echo "Here are the section headings with their tool counts:"
echo
echo "Running: aia -c ${ST_CONFIG} --list-tools --mcp-list | grep '^## '"
echo

aia -c "${ST_CONFIG}" --list-tools --mcp-list 2>/dev/null | grep '^## ' || true

echo
echo "That is more tools than an LLM provider accepts in one request (128)."
echo "Parts 2 and 3 each send a set that fits. In chat (Part 4) AIA's"
echo "TF-IDF tool filter picks the most relevant tools for every turn."
echo
echo

# --- Part 2: shared_tools' local tools ---

echo "--- Part 2: shared_tools' Ruby tools ---"
echo
echo "--no-mcp leaves the MCP servers out, so every local tool is sent."
echo "Each prompt asks the model to name the tool behind each answer."
echo "All of these prompts are read-only."
echo

for prompt_id in shared_tools_system shared_tools_git shared_tools_code shared_tools_web; do
  echo "The prompt file prompts_dir/${prompt_id}.md contains:"
  echo "==="
  cat "prompts_dir/${prompt_id}.md"
  echo "==="
  echo
  echo "Running: aia -c ${ST_CONFIG} --no-output --no-mcp ${prompt_id}"
  echo

  aia -c "${ST_CONFIG}" --no-output --no-mcp "${prompt_id}"

  echo
  echo
done

# --- Part 3: shared_tools' MCP servers ---

echo "--- Part 3: shared_tools' MCP servers ---"
echo
echo "--allowed-tools current_date_time keeps a single local tool, so every"
echo "MCP tool fits in the request."
echo

for prompt_id in shared_tools_mcp_research shared_tools_mcp_think; do
  echo "The prompt file prompts_dir/${prompt_id}.md contains:"
  echo "==="
  cat "prompts_dir/${prompt_id}.md"
  echo "==="
  echo
  echo "Running: aia -c ${ST_CONFIG} --no-output --allowed-tools current_date_time ${prompt_id}"
  echo

  aia -c "${ST_CONFIG}" --no-output --allowed-tools current_date_time "${prompt_id}"

  echo
  echo
done

# --- Part 4: Your turn ---

echo "--- Part 4: Your turn ---"
echo
echo "A chat session with every shared_tools tool and MCP server loaded."
echo "For each message, the TF-IDF tool filter sends the tools that best"
echo "match it. Try asking for things that span several of them, e.g.:"
echo
echo "  Explain the cron expression \"0 7 * * 1-5\" and the date of the next run."
echo "  Search the web for the latest Ruby release, then chart its versions."
echo "  Remember that my favorite gem is shared_tools, then recall it."
echo
echo "Add --verbose to see which tools the filter picked for each turn."
echo
echo "Running: aia -c ${ST_CONFIG} --chat"
echo

if [[ "${BATCH_MODE:-}" == "true" ]]; then
  echo "(Skipping interactive session in batch mode)"
else
  aia -c "${ST_CONFIG}" --chat
fi
