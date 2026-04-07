#!/usr/bin/env bash
# examples/24_decompose.sh
#
# Demonstrates /decompose mode: PromptDecomposer.
#
# A coordinator robot analyzes whether a complex prompt can be
# split into 2-5 independent sub-tasks. If decomposable, specialist
# robots solve each in parallel and results are synthesized into
# a unified answer. Falls back to normal mode if the prompt is not
# decomposable.
#
# How it works in chat:
#   1. Type /decompose  →  AIA sets decomposition mode for next prompt
#   2. Type your complex question  →  coordinator splits, runs, synthesizes
#
# Prerequisites: Run 00_setup_aia.sh first
# Usage: cd examples && bash 24_decompose.sh

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

if ! command -v expect &>/dev/null; then
    echo "ERROR: expect is not installed."
    echo "       Install with: brew install expect"
    exit 1
fi

echo "=== Demo 24: Decompose Mode (PromptDecomposer) ==="
echo
echo "The /decompose directive breaks a complex prompt into"
echo "independent sub-tasks that run in parallel, then synthesizes"
echo "their results into a single coherent response."
echo
echo "Directive mechanics: /decompose sets the mode for the NEXT prompt."
echo "Type /decompose, then type your complex multi-part question."
echo

# --- Part 1: Decomposable multi-part question ---

echo "--- Part 1: A complex decomposable question ---"
echo
echo "This question has several independent parts: explaining a"
echo "concept, listing use cases, and making a recommendation."
echo "The decomposer should split these and run them in parallel."
echo
echo "Running: aia -c ${CONFIG} --chat"
echo

expect <<'EXPECT_SCRIPT'
set timeout 300
log_user 1

spawn aia -c aia_config.yml --chat

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for chat prompt ***"; exit 1 }
}

send "/decompose\r"

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for directive confirmation ***"; exit 1 }
}

send "Explain the difference between TCP and UDP, list the top 3 use cases for each protocol, and recommend which to use for a real-time multiplayer game and explain why.\r"

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for decomposition results ***"; exit 1 }
}

send "exit\r"
expect eof
EXPECT_SCRIPT

drain_terminal
echo
echo

# --- Part 2: Non-decomposable question (fallback) ---

echo "--- Part 2: A simple question (fallback to normal mode) ---"
echo
echo "If the prompt cannot be meaningfully split, the decomposer"
echo "falls back to normal mode and answers directly. This shows"
echo "that /decompose is safe to use on any prompt."
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

send "/decompose\r"

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for directive confirmation ***"; exit 1 }
}

send "What is the capital of France?\r"

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

# --- Part 3: Your turn ---

echo "--- Part 3: Your turn ---"
echo
echo "Try /decompose on any complex, multi-part question or request."
echo "The decomposer works best on prompts that have 2-5 clearly"
echo "independent components."
echo

aia -c "${CONFIG}" --chat
