#!/usr/bin/env bash
# examples/22_chat_mode.sh
#
# Demonstrates interactive chat mode via the --chat flag.
#
# Chat mode opens a persistent conversation where the model
# remembers everything said so far. The key insight: all batch
# processing (prompt, pipeline, context files) completes FIRST,
# then the chat session begins with that full context available.
#
# This demo uses `expect` to script the interactive sessions
# so you can see the full flow without typing anything.
#
# Three scenarios:
#   1. Pure chat — no prompt, just open a conversation
#   2. Prompt then chat — batch processes a prompt, then chat
#   3. Pipeline then chat — runs a full pipeline, then chat
#
# Prerequisites:
#   - Run 00_setup_aia.sh first
#   - expect (pre-installed on macOS, `brew install expect` otherwise)
# Usage: cd examples && bash 22_chat_mode.sh

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# --- Check that expect is available ---

if ! command -v expect &>/dev/null; then
    echo "ERROR: expect is not installed."
    echo "       Install with: brew install expect"
    exit 1
fi

# Drain leaked escape sequences from the terminal input buffer.
# Reline queries cursor position (\e[6n) inside the pty; the
# terminal's responses (\e[row;colR) can leak into bash's stdin
# after expect exits.
drain_terminal() {
    sleep 0.2
    stty sane 2>/dev/null || true
    while IFS= read -r -t 0.2 -n 100 _ 2>/dev/null; do :; done
}

echo "=== Demo 22: Chat Mode ==="
echo
echo "The --chat flag opens an interactive conversation after all"
echo "batch processing completes. The model retains context from"
echo "everything that was processed before the chat session began."
echo
echo "This demo uses 'expect' to script the interactive portions."
echo

# --- Part 1: Pure chat mode ---

echo "--- Part 1: Pure chat (no prompt ID) ---"
echo
echo "Running: aia -c ${CONFIG} --chat"
echo
echo "This starts a conversation with no initial context."
echo "We will ask two questions, then exit."
echo

expect <<'EXPECT_SCRIPT'
set timeout 120
log_user 1

spawn aia -c aia_config.yml --chat

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for chat prompt ***"; exit 1 }
}

send "What are the three primary colors?\r"

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for response ***"; exit 1 }
}

send "Now name a famous painting that uses all three.\r"

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for response ***"; exit 1 }
}

send "exit\r"
expect eof
EXPECT_SCRIPT

drain_terminal
echo
echo

# --- Part 2: Prompt then chat ---

echo "--- Part 2: Prompt then chat ---"
echo
echo "The prompt file prompts_dir/hello.md is processed first in"
echo "batch mode. Then the chat session starts with that response"
echo "already in the conversation history."
echo
echo "Running: aia -c ${CONFIG} --chat hello"
echo

expect <<'EXPECT_SCRIPT'
set timeout 120
log_user 1

spawn aia -c aia_config.yml --chat hello

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for chat prompt ***"; exit 1 }
}

send "What did you just say? Summarize it in one sentence.\r"

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for response ***"; exit 1 }
}

send "exit\r"
expect eof
EXPECT_SCRIPT

drain_terminal
echo
echo

# --- Part 3: Pipeline then chat ---

echo "--- Part 3: Pipeline then chat ---"
echo
echo "This is the power combo: a full pipeline runs to completion,"
echo "THEN the chat session begins with the entire pipeline's"
echo "conversation history available for follow-up questions."
echo
echo "The pipeline is: brainstorm -> evaluate -> pick_best"
echo "(from demos 07). After all three steps finish, we enter"
echo "chat to ask follow-up questions about the results."
echo
echo "Running: aia -c ${CONFIG} --chat --pipeline evaluate,pick_best brainstorm"
echo

expect <<'EXPECT_SCRIPT'
set timeout 180
log_user 1

spawn aia -c aia_config.yml --chat --pipeline evaluate,pick_best brainstorm

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for chat prompt ***"; exit 1 }
}

send "Why did you pick that name over the others?\r"

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for response ***"; exit 1 }
}

send "Suggest a three-word tagline for it.\r"

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for response ***"; exit 1 }
}

send "exit\r"
expect eof
EXPECT_SCRIPT

drain_terminal
echo
echo

# --- Part 4: Chat directives ---

echo "--- Part 4: Chat directives ---"
echo
echo "Inside a chat session, directives like /help, /model,"
echo "/temperature, and /checkpoint are available. These only"
echo "work in chat mode, not in batch mode."
echo
echo "Running: aia -c ${CONFIG} --chat"
echo

expect <<'EXPECT_SCRIPT'
set timeout 120
log_user 1

spawn aia -c aia_config.yml --chat

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for chat prompt ***"; exit 1 }
}

send "/help\r"

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for response ***"; exit 1 }
}

send "exit\r"
expect eof
EXPECT_SCRIPT

drain_terminal

echo
echo

# --- Part 5: Your turn ---

echo "--- Part 5: Your turn ---"
echo
echo "The best way to experience chat mode is to play with it."
echo

aia -c "${CONFIG}" --chat
