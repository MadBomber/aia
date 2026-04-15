#!/usr/bin/env bash
# examples/27_mention_routing.sh
#
# Demonstrates @mention routing in a multi-model network.
#
# In a 2-model chat session, prefix any message with @RobotName
# to direct it to a specific robot. Only that robot responds.
# Robot names are assigned by AIA based on the model:
#   ollama/qwen3     → Tobor  (first robot always gets the name "Tobor")
#   ollama/phi4-mini → Quark
#
# If the @name is not recognized, AIA lists available robot names.
#
# Requires a 2-model network (-m MODEL_A,MODEL_B).
# Requires: phi4-mini (auto-pulled if missing)
#
# Prerequisites: Run 00_setup_aia.sh first
# Usage: cd examples && bash 27_mention_routing.sh

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

if ! command -v expect &>/dev/null; then
    echo "ERROR: expect is not installed."
    echo "       Install with: brew install expect"
    exit 1
fi

MODEL_A="ollama/qwen3"
MODEL_B="ollama/phi4-mini"

echo "=== Demo 27: @mention Routing ==="
echo
echo "In a multi-model network, prefix your message with @RobotName"
echo "to direct it to a specific robot. Only that robot responds."
echo
echo "Using models: ${MODEL_A} vs ${MODEL_B}"
echo "Robot names:  Tobor (qwen3) and Quark (phi4-mini)"
echo

# --- Check that the second model is available ---

if ! ollama list 2>/dev/null | grep -q "^phi4-mini"; then
    echo "Model phi4-mini is not available. Pulling it now ..."
    ollama pull phi4-mini
    echo
fi

# --- Part 1: Route to Tobor (qwen3) ---

echo "--- Part 1: Direct a question to @Tobor ---"
echo
echo "Running: aia -c ${CONFIG} -m ${MODEL_A},${MODEL_B} --chat"
echo

expect <<'EXPECT_SCRIPT'
set timeout 180
log_user 1

spawn aia -c aia_config.yml -m ollama/qwen3,ollama/phi4-mini --chat

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for chat prompt ***"; exit 1 }
}

send "@Tobor What is your favorite metaphor for explaining recursion?\r"

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

# --- Part 2: Route to Quark (phi4-mini) ---

echo "--- Part 2: Direct a question to @Quark ---"
echo
echo "Running: aia -c ${CONFIG} -m ${MODEL_A},${MODEL_B} --chat"
echo

expect <<'EXPECT_SCRIPT'
set timeout 180
log_user 1

spawn aia -c aia_config.yml -m ollama/qwen3,ollama/phi4-mini --chat

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for chat prompt ***"; exit 1 }
}

send "@Quark Describe the CAP theorem in one sentence.\r"

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

# --- Part 3: Unknown @mention lists available robots ---

echo "--- Part 3: Unknown @mention shows available robots ---"
echo
echo "If you @mention a name that doesn't match any robot,"
echo "AIA lists the available robot names so you can correct it."
echo
echo "Running: aia -c ${CONFIG} -m ${MODEL_A},${MODEL_B} --chat"
echo

expect <<'EXPECT_SCRIPT'
set timeout 60
log_user 1

spawn aia -c aia_config.yml -m ollama/qwen3,ollama/phi4-mini --chat

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for chat prompt ***"; exit 1 }
}

send "@nonexistent What is 2 + 2?\r"

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

# --- Part 4: Mix @mention and normal turns ---

echo "--- Part 4: Mix directed and undirected turns ---"
echo
echo "In a session you can freely mix @mention turns (one robot)"
echo "with normal turns (all robots). This shows how to hold a"
echo "selective conversation across a network."
echo
echo "Running: aia -c ${CONFIG} -m ${MODEL_A},${MODEL_B} --chat"
echo

if [[ "${BATCH_MODE:-}" == "true" ]]; then
  echo "(Skipping interactive session in batch mode)"
else
  aia -c "${CONFIG}" -m "${MODEL_A},${MODEL_B}" --chat
fi
