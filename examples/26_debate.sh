#!/usr/bin/env bash
# examples/26_debate_fixed.sh
#
# Fixed version of the debate demonstration script
#
# Demonstrates /debate mode: DebateHandler.
#
# Two robots debate a topic across multiple rounds. Each round,
# every robot responds to the previous arguments. Stops when any
# robot says CONVERGED or after 5 rounds. Uses SimilarityScorer
# to also detect convergence when responses become too similar.
#
# Requires a 2-model network (-m MODEL_A,MODEL_B).

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

if ! command -v expect &>/dev/null; then
    echo "ERROR: expect is not installed."
    echo "       Install with: brew install expect"
    exit 1
fi

MODEL_A="gpt-4.1"
MODEL_B="gpt-4.1-mini"

echo "=== Demo 26: Debate Mode (DebateHandler) ==="
echo
echo "The /debate directive pits two robots against each other in"
echo "a structured multi-round debate. Each robot sees what the"
echo "other said in the previous round and responds. The debate"
echo "ends when a robot says CONVERGED or after 5 rounds."
echo
echo "Using models: ${MODEL_A} vs ${MODEL_B}"
echo "Robot names:  Tobor (gpt-4.1) and Vanguard (gpt-4.1-mini)"
echo

# --- Part 1: A technical debate ---

echo "--- Part 1: Technical debate ---"
echo
echo "Both models will debate the best approach to API design."
echo "Watch how their positions evolve across rounds."
echo
echo "Running: aia -c ${CONFIG} -m ${MODEL_A},${MODEL_B} --chat"
echo

# Create the expect script with proper variable substitution
expect -c "
set timeout 600
log_user 1

spawn aia -c ${CONFIG} -m ${MODEL_A},${MODEL_B} --chat

expect {
  \"#=> \" {}
  timeout { puts \"\n*** Timed out waiting for chat prompt ***\"; exit 1 }
}

send \"/debate\r\"

expect {
  \"#=> \" {}
  timeout { puts \"\n*** Timed out waiting for directive confirmation ***\"; exit 1 }
}

send \"REST vs GraphQL: which is the better default choice for a new web API in 2025, and why?\r\"

expect {
  \"#=> \" {}
  timeout { puts \"\n*** Timed out waiting for debate results ***\"; exit 1 }
}

send \"exit\r\"
expect eof
"

drain_terminal
echo
echo

# --- Part 2: Your turn ---

echo "--- Part 2: Your turn ---"
echo
echo "Try /debate on any topic where two perspectives are valuable:"
echo "architecture decisions, tradeoffs, design choices, or even"
echo "open-ended questions where you want multiple viewpoints stress-tested."
echo
echo "Running: aia -c ${CONFIG} -m ${MODEL_A},${MODEL_B} --chat"
echo

if [[ "${BATCH_MODE:-}" == "true" ]]; then
  echo "(Skipping interactive session in batch mode)"
else
  aia -c "${CONFIG}" -m "${MODEL_A},${MODEL_B}" --chat
fi
