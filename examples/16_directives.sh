#!/usr/bin/env bash
# examples/16_directives.sh
#
# Demonstrates AIA directives — special functions available
# inside prompt files via ERB and in chat mode via /command.
#
# This demo focuses on the 'include' directive, which inserts
# the contents of another file into the prompt at render time.
#
# Prerequisites: Run 00_setup_aia.sh first.
# Usage: cd examples && bash 16_directives.sh

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo "=== Demo 16: Directives ==="
echo
echo "Directives are built-in functions available in prompts (via ERB)"
echo "and in chat mode (via /command). Here are the available directives:"
echo
echo "  Prompt Manager Core:"
echo "    include   - Include recursively and render another prompt file(s)"
echo "    insert    - Insert (non-recursive) raw file contents (aliases: read)"
echo
echo "The remaining directives are more useful as /commands in chat mode:"
echo
echo "  Configuration:"
echo "    /config   - View or set configuration values"
echo "    /model    - View or change the AI model"
echo "    /temp     - Set the temperature parameter"
echo "    /top_p    - Set the top_p parameter"
echo
echo "  Context:"
echo "    /checkpoint - Create a named checkpoint"
echo "    /restore    - Restore to a previous checkpoint"
echo "    /clear      - Clear the conversation context"
echo "    /review     - Display the current context"
echo "    /list       - List all available checkpoints"
echo
echo "  Execution:"
echo "    /ruby     - Execute Ruby code"
echo "    /speak    - Use text-to-speech"
echo
echo "  Model:"
echo "    /models   - List all available AI models"
echo "    /compare  - Compare responses from multiple models"
echo
echo "  Utility:"
echo "    /tools    - List available tools"
echo "    /terse    - Request concise responses"
echo "    /robot    - Display ASCII robot art"
echo "    /help     - Show directive help"
echo
echo "  Web & File:"
echo "    /web      - Fetch and include webpage content"
echo "    /skills   - List available Claude Code skills"
echo "    /skill    - Include a Claude Code skill"
echo "    /paste    - Paste from the system clipboard"
echo

# --- Using include in a prompt ---

echo "--- Using 'include' in a prompt file ---"
echo
echo "The included file prompts_dir/includes/ruby_facts.md contains:"
echo "==="
cat prompts_dir/includes/ruby_facts.md
echo "==="
echo
echo "The prompt file prompts_dir/quiz_with_include.md contains:"
echo "==="
cat prompts_dir/quiz_with_include.md
echo "==="
echo
echo "The <%= include 'includes/ruby_facts.md' %> directive pulls"
echo "in the facts file at render time, so the model sees the"
echo "combined content as one prompt."
echo
echo "Running: aia -c ${CONFIG} --no-output quiz_with_include"
echo

aia -c "${CONFIG}" --no-output quiz_with_include
