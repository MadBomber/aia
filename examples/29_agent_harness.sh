#!/usr/bin/env bash
# examples/29_agent_harness.sh
#
# Demonstrates AIA as a full agent harness with a three-tier model:
#
#   Tier 1 — Tobor (orchestrator)
#     Primary robot given an orchestrator role via --role orchestrator.
#     Receives tasks and decides how to coordinate the team.
#
#   Tier 2 — Lead agents (spawned on demand)
#     Specialist robots created with /spawn <type> for domain expertise.
#     Each lead agent has a focused system prompt and handles a workstream.
#
#   Tier 3 — Task runners (network robots)
#     The models in the -m list execute parallel workstreams via /decompose.
#     Tobor synthesizes their results.
#
# Parts:
#   1. Orchestrator role — Tobor describes its coordination strategy
#   2. Spawn a lead agent — create a security-expert, route a task to it
#   3. Parallel workstreams — /decompose a multi-dimension design review
#   4. Free session — try your own orchestration scenario
#
# Prerequisites: Run 00_setup_aia.sh first
# Requires: phi4-mini (auto-pulled if missing)
# Usage: cd examples && bash 29_agent_harness.sh

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

if ! command -v expect &>/dev/null; then
    echo "ERROR: expect is not installed."
    echo "       Install with: brew install expect"
    exit 1
fi

MODEL_A="ollama/qwen3"
MODEL_B="ollama/phi4-mini"
ORCH_CONFIG="aia_config_orchestrator.yml"

echo "=== Demo 29: AIA Agent Harness ==="
echo
echo "AIA contains every component needed to operate as a full agent harness:"
echo "  - Orchestrator role  (system prompt set in aia_config_orchestrator.yml)"
echo "  - Lead agents        (/spawn <type> creates specialists on demand)"
echo "  - Task runners       (/decompose distributes parallel workstreams)"
echo "  - Synthesis          (orchestrator assembles results into a final answer)"
echo
echo "This demo wires those components together so Tobor acts as a project"
echo "director coordinating a team, not just a single-model responder."
echo

# --- Check that the second model is available ---

if ! ollama list 2>/dev/null | grep -q "^phi4-mini"; then
    echo "Model phi4-mini is not available. Pulling it now ..."
    ollama pull phi4-mini
    echo
fi

# --- Part 1: Orchestrator self-awareness ---

echo "--- Part 1: Orchestrator role ---"
echo
echo "Tobor starts with an orchestrator system prompt (set in aia_config_orchestrator.yml)."
echo "It understands its mandate: assess incoming tasks, choose a coordination"
echo "strategy (/spawn, /decompose, /delegate, or direct), and synthesize results."
echo
echo "Running: aia -c ${ORCH_CONFIG} --chat"
echo

expect <<'EXPECT_SCRIPT'
set timeout 120
log_user 1

spawn aia -c aia_config_orchestrator.yml --chat

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for chat prompt ***"; exit 1 }
}

send "You will receive a complex engineering request shortly. Without executing anything yet, briefly explain which coordination strategy you would use and why: designing a production-ready REST API with authentication, rate limiting, and observability.\r"

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

# --- Part 2: Spawn a lead agent ---

echo "--- Part 2: Spawn a specialist lead agent ---"
echo
echo "Tobor (orchestrator) spawns a 'security-expert' lead agent on demand."
echo "The task is routed to the specialist rather than answered by Tobor directly."
echo "This shows Tier 2: orchestrator → specialist delegation."
echo
echo "Running: aia -c ${ORCH_CONFIG} -m ${MODEL_A},${MODEL_B} --chat"
echo

expect <<'EXPECT_SCRIPT'
set timeout 120
log_user 1

spawn aia -c aia_config_orchestrator.yml -m ollama/qwen3,ollama/phi4-mini --chat

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for chat prompt ***"; exit 1 }
}

send "/spawn security-expert\r"

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for spawn confirmation ***"; exit 1 }
}

send "List the five most critical security controls that must be in place before a REST API is exposed to the public internet.\r"

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

# --- Part 3: Parallel workstreams via /decompose ---

echo "--- Part 3: Parallel workstreams (Tier 3 task runners) ---"
echo
echo "Tobor receives a multi-dimension design review. /decompose splits it"
echo "into independent workstreams, Tobor and Quark each handle different"
echo "dimensions concurrently, and Tobor synthesizes the final assessment."
echo
echo "Running: aia -c ${ORCH_CONFIG} -m ${MODEL_A},${MODEL_B} --chat"
echo

expect <<'EXPECT_SCRIPT'
set timeout 600
log_user 1

spawn aia -c aia_config_orchestrator.yml -m ollama/qwen3,ollama/phi4-mini --chat

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for chat prompt ***"; exit 1 }
}

send "/decompose\r"

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for directive confirmation ***"; exit 1 }
}

send "Review this proposed system design and evaluate it across four dimensions: (1) architectural soundness of microservices on Kubernetes, (2) data layer choices of PostgreSQL + Redis, (3) operational complexity and team readiness, (4) scaling strategy for 10x traffic growth.\r"

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

# --- Part 4: Your orchestration session ---

echo "--- Part 4: Your turn ---"
echo
echo "An open orchestration session with Tobor as your project director."
echo "Try any combination of:"
echo "  /spawn <specialist-type>   create a domain expert lead agent"
echo "  /decompose                 split a multi-part task across the team"
echo "  /delegate                  structured step-by-step execution plan"
echo "  /debate                    have Tobor and Quark stress-test a decision"
echo "  @Tobor or @Quark           address a specific robot directly"
echo
echo "Running: aia -c ${ORCH_CONFIG} -m ${MODEL_A},${MODEL_B} --chat"
echo

aia -c "${ORCH_CONFIG}" -m "${MODEL_A},${MODEL_B}" --chat
