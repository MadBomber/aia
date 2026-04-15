#!/usr/bin/env bash
# examples/25_spawn.sh
#
# Demonstrates /spawn mode: SpawnHandler.
#
# Dynamically creates a specialist robot on demand. You can name
# the specialist type (/spawn ruby-expert) or let AIA auto-detect
# from the content of your next prompt (/spawn with no args).
# Spawned specialists are cached and reused within the session.
#
# How it works in chat:
#   1. Type /spawn [optional type]  →  AIA sets spawn mode
#   2. Type your question  →  specialist robot answers
#
# Prerequisites: Run 00_setup_aia.sh first
# Usage: cd examples && bash 25_spawn.sh

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

if ! command -v expect &>/dev/null; then
    echo "ERROR: expect is not installed."
    echo "       Install with: brew install expect"
    exit 1
fi

echo "=== Demo 25: Spawn Mode (SpawnHandler) ==="
echo
echo "The /spawn directive creates a specialist robot to answer"
echo "a domain-specific question. Specialists are cached for the"
echo "session so repeated questions in the same domain reuse the"
echo "same specialist robot."
echo
echo "Directive mechanics: /spawn [type] sets the mode for the NEXT"
echo "prompt. Named type: /spawn security-expert. Auto-detect: /spawn"
echo

# --- Part 1: Explicit specialist type ---

echo "--- Part 1: Explicit specialist (/spawn security-expert) ---"
echo
echo "We'll explicitly request a security expert to review a"
echo "common code vulnerability pattern."
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

send "/spawn security-expert\r"

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for directive confirmation ***"; exit 1 }
}

send "What are the top 3 SQL injection prevention techniques and how does parameterized query binding work?\r"

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for specialist response ***"; exit 1 }
}

send "exit\r"
expect eof
EXPECT_SCRIPT

drain_terminal
echo
echo

# --- Part 2: Auto-detect specialist ---

echo "--- Part 2: Auto-detect specialist (/spawn with no args) ---"
echo
echo "Without a type, AIA asks the primary robot to determine what"
echo "kind of specialist would best answer the next question."
echo "The primary robot chooses the role and writes the specialist's"
echo "system prompt automatically."
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

send "/spawn\r"

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for directive confirmation ***"; exit 1 }
}

send "What database indexing strategies should I consider for a write-heavy time-series workload in PostgreSQL?\r"

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for specialist response ***"; exit 1 }
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
echo "Try /spawn ruby-expert, /spawn data-scientist, /spawn devops,"
echo "or just /spawn and let AIA decide. Ask domain-specific questions"
echo "that benefit from a focused specialist perspective."
echo

if [[ "${BATCH_MODE:-}" == "true" ]]; then
  echo "(Skipping interactive session in batch mode)"
else
  aia -c "${CONFIG}" --chat
fi
