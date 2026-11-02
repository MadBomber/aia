#!/usr/bin/env bash
# examples/16_directives.sh
#
# Demonstrates AIA directives — special functions available
# inside prompt files via ERB and in chat mode via /command.
#
# Part 1 demonstrates the 'include' directive, which inserts
# the contents of another file into the prompt at render time.
# Part 2 shows how to create and load your own custom directive.
#
# Prerequisites: Run 00_setup_aia.sh first.
# Usage: cd examples && bash 16_directives.sh

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo "=== Demo 16: Directives ==="
echo
cat <<'EOF'
Directives are built-in functions available in prompts (via ERB)
and in chat mode (via /command). Run /help in a chat for the full,
current list. The main ones:

  Prompt Manager core (in prompt files):
    include   - Include and render another prompt file
    insert    - Insert a file's raw contents (alias: read)

  Configuration:
    /config   - View or set configuration values (alias: /cfg)
    /model    - View or change the AI model
    /temperature, /top_p - Set sampling parameters (aliases: /temp, /topp)
    /cost     - Session cost and token metrics as CSV

  Context:
    /checkpoint  - Create a named checkpoint (aliases: /ckp, /cp)
    /restore     - Restore a checkpoint
    /clear       - Clear the conversation context
    /review      - Show the conversation context (alias: /context)
    /checkpoints - List checkpoints

  Execution:
    /ruby     - Run Ruby code (needs --allow-ruby-eval)
    /say      - Speak text aloud
    /verify, /decompose, /debate, /delegate, /spawn, /concurrent, /orchestrate
              - Special handling for your next message
    /add_recruit, /drop_recruit, /reskill - Manage the crew

  Models:
    /models   - Search available models (aliases: /available_models, /am, ...)
    /compare  - Compare responses from several models (alias: /cmp)

  Tasks (TrakFlow):
    /tasks, /task, /plan

  Utility:
    /tools, /mcp, /plugins, /robots, /robot, /help

  Web and files:
    /webpage  - Fetch a webpage (aliases: /web, /website)
    /skills   - List your AIA skills
    /skill    - Include an AIA skill
    /paste    - Paste from the clipboard (alias: /clipboard)

EOF

# --- Part 1: Using include in a prompt ---

echo "--- Part 1: Using 'include' in a prompt file ---"
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

echo
echo

# --- Part 2: Creating a custom directive ---

echo "--- Part 2: Creating and using a custom directive ---"
echo
echo "You can extend AIA with your own directives. A custom directive"
echo "is a Ruby class that inherits from AIA::Directive. Define methods"
echo "with a 'desc' line above them and they become available in both"
echo "ERB prompts and as /commands in chat mode."
echo
echo "The file directives/timestamp_directive.rb contains:"
echo "==="
cat directives/timestamp_directive.rb
echo "==="
echo
echo "The prompt file prompts_dir/with_timestamp.md uses it:"
echo "==="
cat prompts_dir/with_timestamp.md
echo "==="
echo
echo "Load the custom directive with --tools and it becomes available"
echo "alongside the built-in directives."
echo
echo "Running: aia -c ${CONFIG} --no-output --tools directives/timestamp_directive.rb with_timestamp"
echo

aia -c "${CONFIG}" --no-output --tools directives/timestamp_directive.rb with_timestamp
