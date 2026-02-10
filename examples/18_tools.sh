#!/usr/bin/env bash
# examples/18_tools.sh
#
# Demonstrates loading RubyLLM::Tool classes via --require so
# the model can call them as function tools during inference.
#
# This demo uses the shared_tools gem, which provides a library
# of ready-made RubyLLM::Tool subclasses. AIA discovers them
# automatically after the gem is required.
#
# Prerequisites:
#   - Run 00_setup_aia.sh first
#   - gem install shared_tools
# Usage: cd examples && bash 18_tools.sh

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo "=== Demo 18: Tools via --require ==="
echo
echo "The --rq (--require) flag loads Ruby gems at startup."
echo "If a gem defines RubyLLM::Tool subclasses, AIA discovers"
echo "them automatically and makes them available to the model."
echo
echo "The shared_tools gem provides tools like:"
echo "  - current_date_time  — current date, time, timezone"
echo "  - system_info        — OS, CPU, memory, disk details"
echo "  - dns                — DNS lookups and record queries"
echo "  - cron               — parse and explain cron expressions"
echo "  - clipboard          — read/write the system clipboard"
echo "  and more."
echo

# --- Check that shared_tools is installed ---

if ! gem list shared_tools --installed > /dev/null 2>&1; then
  echo "ERROR: The shared_tools gem is not installed."
  echo "       Install with: gem install shared_tools"
  exit 1
fi

echo "The prompt file prompts_dir/use_tools.md contains:"
echo "==="
cat prompts_dir/use_tools.md
echo "==="
echo
echo "Running: aia -c ${CONFIG} --no-output --rq shared_tools use_tools"
echo
echo "The model will call tools to get live data, then summarize"
echo "the results."
echo

aia -c "${CONFIG}" --no-output --rq shared_tools use_tools
