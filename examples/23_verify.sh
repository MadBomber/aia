#!/usr/bin/env bash
# examples/23_verify.sh
#
# Demonstrates /verify mode: VerificationNetwork.
#
# Two robots independently answer the same question with
# slightly different system prompts, then a third "reconciler"
# robot compares both answers, identifies agreements and
# disagreements, and produces a final verified answer.
#
# All three robots use the same model -- no second model needed.
#
# How it works in chat:
#   1. Type /verify  →  AIA sets verification mode for next prompt
#   2. Type your question  →  two verifiers + reconciler run
#
# Prerequisites: Run 00_setup_aia.sh first
# Usage: cd examples && bash 23_verify.sh

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

if ! command -v expect &>/dev/null; then
    echo "ERROR: expect is not installed."
    echo "       Install with: brew install expect"
    exit 1
fi

drain_terminal() {
    sleep 0.2
    stty sane 2>/dev/null || true
    while IFS= read -r -t 0.2 -n 100 _ 2>/dev/null; do :; done
}

echo "=== Demo 23: Verify Mode (VerificationNetwork) ==="
echo
echo "The /verify directive runs two independent robots on the same"
echo "question, then a third reconciler robot compares the answers"
echo "and produces a final verified response."
echo
echo "Directive mechanics: /verify sets the mode for the NEXT prompt."
echo "Type /verify, then type your question on the next line."
echo

# --- Part 1: Verify a factual question ---

echo "--- Part 1: Verify a factual claim ---"
echo
echo "We'll type /verify, then ask about the causes of the 2008"
echo "financial crisis. Two verifiers answer independently; the"
echo "reconciler synthesizes a final, checked response."
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

send "/verify\r"

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for directive confirmation ***"; exit 1 }
}

send "What were the three main causes of the 2008 global financial crisis?\r"

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for verification results ***"; exit 1 }
}

send "exit\r"
expect eof
EXPECT_SCRIPT

drain_terminal
echo
echo

# --- Part 2: Verify a technical question ---

echo "--- Part 2: Verify a technical explanation ---"
echo
echo "Verification is especially useful for technical topics where"
echo "subtle errors can slip through. Two independent passes catch"
echo "more mistakes than one."
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

send "/verify\r"

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for directive confirmation ***"; exit 1 }
}

send "Explain how TCP's three-way handshake works and why it guarantees reliable connection establishment.\r"

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for verification results ***"; exit 1 }
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
echo "Try /verify on any factual or technical question where you"
echo "want cross-checked confidence rather than a single answer."
echo

aia -c "${CONFIG}" --chat
