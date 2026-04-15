#!/usr/bin/env bash
# examples/28_model_switching.sh
#
# Demonstrates /model directive: switching models mid-conversation.
#
# The /model directive rebuilds the active robot with a new model
# while preserving the full conversation history. Context is
# transferred so the new model can see everything discussed so far.
#
# Note: Natural language model switching ("use phi4-mini instead")
# is detected by ModelSwitchHandler but currently stubbed. Use
# /model directly for reliable in-session model changes.
#
# Prerequisites:
#   - Run 00_setup_aia.sh first
#   - phi4-mini model (auto-pulled if missing)
# Usage: cd examples && bash 28_model_switching.sh

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

if ! command -v expect &>/dev/null; then
    echo "ERROR: expect is not installed."
    echo "       Install with: brew install expect"
    exit 1
fi

MODEL_A="ollama/qwen3"
MODEL_B="ollama/phi4-mini"

echo "=== Demo 28: Model Switching (/model directive) ==="
echo
echo "The /model directive switches the active model mid-conversation."
echo "Conversation history is transferred so the new model has"
echo "full context of everything discussed before the switch."
echo
echo "Starting model: ${MODEL_A}"
echo "Switch target:  ${MODEL_B}"
echo

# --- Check that the second model is available ---

if ! ollama list 2>/dev/null | grep -q "^phi4-mini"; then
    echo "Model phi4-mini is not available. Pulling it now ..."
    ollama pull phi4-mini
    echo
fi

# --- Part 1: Ask a question, switch models, ask a follow-up ---

echo "--- Part 1: Ask a question, switch models, ask a follow-up ---"
echo
echo "We'll ask a question with ${MODEL_A}, switch to ${MODEL_B},"
echo "then ask a follow-up. The second model should reference the"
echo "first exchange because history is preserved across the switch."
echo
echo "Running: aia -c ${CONFIG} --chat"
echo

expect <<'EXPECT_SCRIPT'
set timeout 180
log_user 1

spawn aia -c aia_config.yml --chat

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for chat prompt ***"; exit 1 }
}

send "Name three key differences between a process and a thread.\r"

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for first response ***"; exit 1 }
}

send "/model ollama/phi4-mini\r"

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for model switch ***"; exit 1 }
}

send "Based on what you just said, which is more appropriate for a CPU-bound image processing pipeline?\r"

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for follow-up response ***"; exit 1 }
}

send "exit\r"
expect eof
EXPECT_SCRIPT

drain_terminal
echo
echo

# --- Part 2: Your turn ---

echo "--- Part 2: Your turn ---"
echo
echo "Use /model <name> any time during a chat to switch models."
echo "The new model picks up the full conversation history."
echo "You can switch back and forth as many times as you like."
echo
echo "Running: aia -c ${CONFIG} --chat"
echo

if [[ "${BATCH_MODE:-}" == "true" ]]; then
  echo "(Skipping interactive session in batch mode)"
else
  aia -c "${CONFIG}" --chat
fi
