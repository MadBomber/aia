#!/usr/bin/env bash
# examples/29_agent_harness.sh
#
# Demonstrates AIA as a full agent harness using 3-tier layered orchestration.
#
# A complete application requirements document is fed to the /orchestrate
# directive. AIA runs a three-tier execution:
#
#   Tier 1 — Tobor (orchestrator)
#     Reads the full requirements and decomposes them into independent
#     architectural layers (e.g. Infrastructure, Data Models, Auth, Routes, Views).
#
#   Tier 2 — Lead agents (one per layer)
#     Each lead agent receives its layer's requirements and further decomposes
#     them into specific implementation tasks, assigning a specialist type to
#     each task (e.g. sequel-migration-writer, sinatra-route-builder).
#
#   Tier 3 — Specialist robots (one per task)
#     Each specialist receives a focused, concrete task and produces an actual
#     implementation artifact: a code file, migration, route handler, or spec.
#
#   Synthesis
#     Each lead agent synthesizes its layer's artifacts into a summary.
#     Tobor then synthesizes all layer summaries into a final integration report.
#
# The application being built: TaskFlow — a multi-user project and task
# management web app using Ruby, Sinatra, Sequel (SQLite), and ERB templates.
# Full requirements: examples/requirements/sinatra_taskflow_app.md
#
# Prerequisites: Run 00_setup_aia.sh first (OPENAI_API_KEY must be set)
# Requires: expect (brew install expect)
# Usage: cd examples && bash 29_agent_harness.sh

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

if ! command -v expect &>/dev/null; then
    echo "ERROR: expect is not installed."
    echo "       Install with: brew install expect"
    exit 1
fi

MODEL_A="gpt-4.1"
MODEL_B="gpt-4.1-mini"
ORCH_CONFIG="aia_config_orchestrator.yml"
REQUIREMENTS="requirements/sinatra_taskflow_app.md"

echo "=== Demo 29: AIA Agent Harness — 3-Tier Layered Orchestration ==="
echo
echo "Application being built:"
echo "  TaskFlow — a multi-user project and task management web app"
echo "  Stack: Ruby + Sinatra + Sequel (SQLite) + ERB + Bootstrap 5"
echo
echo "Execution model:"
echo "  Tier 1  Tobor (orchestrator) decomposes requirements into layers"
echo "  Tier 2  One lead agent per layer decomposes into specialist tasks"
echo "  Tier 3  One specialist per task produces the implementation artifact"
echo

if [[ ! -f "${REQUIREMENTS}" ]]; then
    echo "ERROR: Requirements file not found: ${REQUIREMENTS}"
    echo "       Expected at: examples/requirements/sinatra_taskflow_app.md"
    exit 1
fi

# --- Orchestration run ---

echo "--- Orchestrated build: /orchestrate ---"
echo
echo "The directive /orchestrate enables 3-tier mode for the next prompt."
echo "The next message is the full application requirements document."
echo "AIA will:"
echo "  1. Decompose requirements into architectural layers"
echo "  2. Spawn a lead agent for each layer"
echo "  3. Have each lead spawn specialists for its tasks"
echo "  4. Collect artifacts and synthesize across all layers"
echo
echo "Requirements document: ${REQUIREMENTS}"
echo "Running: aia -c ${ORCH_CONFIG} -m ${MODEL_A},${MODEL_B} --chat"
echo
echo "Note: This demonstration runs 3+ tiers of agents in sequence."
echo "      Each layer spawns 2-4 specialists. Allow 10-20 minutes"
echo "      depending on OpenAI API response times."
echo

REQUIREMENTS_CONTENT=$(cat "${REQUIREMENTS}")

expect <<EXPECT_SCRIPT
set timeout 1800
log_user 1

spawn aia -c aia_config_orchestrator.yml -m gpt-4.1,gpt-4.1-mini --chat

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for chat prompt ***"; exit 1 }
}

send "/orchestrate\r"

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for directive confirmation ***"; exit 1 }
}

send {${REQUIREMENTS_CONTENT}}
send "\r"

expect {
  "#=> " {}
  timeout { puts "\n*** Timed out waiting for orchestration to complete ***"; exit 1 }
}

send "exit\r"
expect eof
EXPECT_SCRIPT

drain_terminal
echo
echo

# --- Show what was built ---

echo "--- Generated application files ---"
echo

BUILD_DIR=$(ls -dt orchestrated_build_* 2>/dev/null | head -1)

if [[ -z "${BUILD_DIR}" ]]; then
    echo "No build directory found. The orchestration may not have completed."
else
    echo "Build directory: ${BUILD_DIR}"
    echo
    echo "Files produced by the agent team:"
    find "${BUILD_DIR}" -type f | sort | grep -v INTEGRATION_REPORT.md | while read -r f; do
        rel="${f#${BUILD_DIR}/}"
        lines=$(wc -l < "${f}" 2>/dev/null | tr -d ' ' || echo "?")
        printf "  %-50s  (%s lines)\n" "${rel}" "${lines}"
    done
    echo
    REPORT="${BUILD_DIR}/INTEGRATION_REPORT.md"
    if [[ -f "${REPORT}" ]]; then
        echo "--- INTEGRATION_REPORT.md ---"
        echo
        cat "${REPORT}"
        echo
    fi

    # Show a sample generated file (first non-report Ruby file found)
    SAMPLE=$(find "${BUILD_DIR}" -type f -name "*.rb" | sort | head -1)
    if [[ -n "${SAMPLE}" ]]; then
        echo "--- Sample artifact: ${SAMPLE#${BUILD_DIR}/} ---"
        echo
        cat "${SAMPLE}"
        echo
    fi
fi

# --- Interactive session ---

echo "--- Interactive orchestration session ---"
echo
echo "The same session is now open for you to:"
echo "  /orchestrate   run 3-tier orchestration on any requirements prompt"
echo "  /spawn <type>  create a specialist lead agent for a focused task"
echo "  /decompose     parallel workstreams for multi-part questions"
echo "  @Tobor         address the orchestrator directly"
echo "  @Quark         address the specialist network robot directly"
echo
echo "Running: aia -c ${ORCH_CONFIG} -m ${MODEL_A},${MODEL_B} --chat"
echo

if [[ "${BATCH_MODE:-}" == "true" ]]; then
  echo "(Skipping interactive session in batch mode)"
else
  aia -c "${ORCH_CONFIG}" -m "${MODEL_A},${MODEL_B}" --chat
fi
