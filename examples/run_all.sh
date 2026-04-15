#!/usr/bin/env bash
# examples/run_all.sh
#
# Runs all example demo scripts in order and captures output.
#
# The output is saved to a timestamped file for comparison against
# future runs — a super-meta integration test. Since LLM responses
# are non-deterministic, exact diffs won't match; look for structural
# differences (missing sections, crashes, changed command output).
#
# What it skips:
#   - 00_setup_aia.sh     — run manually first (pulls models, writes config)
#   - 15_parameters.sh    — Part 2 prompts interactively for a required param
#   - 20_mcp_servers.sh   — requires Node.js/npx + MCP filesystem server
#   - 22_chat_mode.sh     — interactive chat (Parts 1-4 use expect; Part 5
#                           opens a live session)
#   - 29_agent_harness.sh — 3-tier orchestration (10-20 min runtime)
#
# Scripts 23-28 run with BATCH_MODE=true, which skips their interactive
# "your turn" sections but still executes the automated expect-based parts.
#
# Prerequisites:
#   - Run 00_setup_aia.sh first
#   - Ollama running with qwen3 model available
#
# Usage:
#   cd examples
#   bash run_all.sh                  # run and save output
#   bash run_all.sh --no-save        # run without saving (just print)
#   diff output/run_PREV.log output/run_LATEST.log  # compare runs
#
# Exit codes:
#   0 — all scripts completed (some may have non-fatal warnings)
#   1 — setup not done or a script failed fatally

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# --- Usage ---

usage() {
  cat <<'USAGE'
Usage: bash run_all.sh [OPTIONS]

Run all non-interactive AIA example scripts and capture output.

Options:
  -h, --help      Show this help message and exit
  --no-save       Print output to the terminal only (do not save a log file)

By default the output is saved to examples/output/run_YYYYMMDD_HHMMSS.log.
Since LLM responses are non-deterministic, exact diffs between runs won't
match; look for structural differences (missing sections, crashes, changed
command output).

Saving output with tee:
  bash run_all.sh --no-save 2>&1 | tee my_run.log

  Use --no-save so the script does not write its own log file, then pipe
  through tee to send output to both the terminal and your chosen file.

Comparing runs:
  diff output/run_PREV.log output/run_LATEST.log

Skipped scripts (require manual or interactive setup):
  00_setup_aia.sh    — run manually first (pulls models, writes config)
  15_parameters.sh   — Part 2 prompts interactively for a required param
  20_mcp_servers.sh  — requires Node.js/npx + MCP filesystem server
  22_chat_mode.sh    — interactive chat session
  29_agent_harness.sh — 3-tier orchestration (10-20 min runtime)

Scripts 23-28 run with BATCH_MODE=true, which skips their interactive
"your turn" sections but still runs the automated expect-based parts.

Prerequisites:
  1. Run 00_setup_aia.sh first
  2. Ollama running with the qwen3 model available

Exit codes:
  0  All scripts completed (some may have non-fatal warnings)
  1  Setup not done or a script failed fatally
USAGE
}

# --- Parse flags ---

SAVE_OUTPUT=true
case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  --no-save)
    SAVE_OUTPUT=false
    ;;
esac

# --- Pre-flight checks ---

if [[ ! -f "aia_config.yml" ]]; then
  echo "ERROR: aia_config.yml not found."
  echo "       Run 00_setup_aia.sh first."
  exit 1
fi

if ! command -v aia &>/dev/null; then
  echo "ERROR: aia is not installed."
  exit 1
fi

# --- Scripts to run ---
# Order matters: numbered scripts build on each other conceptually.
# Scripts are listed explicitly so we can annotate skips.

SCRIPTS=(
  01_basic_usage.sh
  02_frontmatter.sh
  03_shell_integration.sh
  04_erb_templating.sh
  05_shell_then_erb.sh
  06_prompt_chaining.sh
  07_pipeline.sh
  08_context_files.sh
  09_roles.sh
  10_stdin_piping.sh
  11_multi_model.sh
  12_token_usage.sh
  13_cost_tracking.sh
  14_output_file.sh
  # 15_parameters.sh — skipped: Part 2 blocks on interactive input
  16_directives.sh
  17_require_and_conditionals.sh
  18_tools.sh
  19_local_tools.sh
  # 20_mcp_servers.sh — skipped: requires npx + MCP server
  21_executable_prompts.sh
  # 22_chat_mode.sh — skipped: interactive chat session
  23_verify.sh
  24_decompose.sh
  25_spawn.sh
  26_debate.sh
  27_mention_routing.sh
  28_model_switching.sh
  # 29_agent_harness.sh — skipped: 3-tier orchestration, 10-20 min runtime
)

SKIPPED=(
  "15_parameters.sh  (interactive parameter input)"
  "20_mcp_servers.sh (requires Node.js/npx + MCP server)"
  "22_chat_mode.sh   (interactive chat session)"
  "29_agent_harness.sh (3-tier orchestration, 10-20 min runtime)"
)

# --- Set up output ---

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
OUTPUT_DIR="${SCRIPT_DIR}/output"
OUTPUT_FILE="${OUTPUT_DIR}/run_${TIMESTAMP}.log"

if [[ "${SAVE_OUTPUT}" == true ]]; then
  mkdir -p "${OUTPUT_DIR}"
fi

# --- Banner ---

banner() {
  cat <<EOF
================================================================================
  AIA Examples — Full Run
  Date:    $(date '+%Y-%m-%d %H:%M:%S')
  AIA:     $(aia --version 2>/dev/null || echo "unknown")
  Ruby:    $(ruby --version 2>/dev/null | head -1)
  Model:   $(grep 'name:' aia_config.yml | head -1 | sed 's/.*name: *//')
================================================================================

Skipped scripts:
$(printf '  - %s\n' "${SKIPPED[@]}")

Running ${#SCRIPTS[@]} scripts ...

EOF
}

# --- Run a single script ---

run_script() {
  local script="$1"
  local index="$2"
  local total="$3"
  local status

  echo "──────────────────────────────────────────────────────────────"
  echo "  [${index}/${total}] ${script}"
  echo "──────────────────────────────────────────────────────────────"
  echo

  if [[ ! -f "${script}" ]]; then
    echo "  SKIP: file not found"
    echo
    return 0
  fi

  bash "${script}" 2>&1
  status=$?

  echo
  if [[ ${status} -eq 0 ]]; then
    echo "  ✓ ${script} completed (exit ${status})"
  else
    echo "  ✗ ${script} FAILED (exit ${status})"
  fi
  echo

  return ${status}
}

# Scripts that require BATCH_MODE=true to skip their interactive sessions
BATCH_MODE_SCRIPTS=(
  23_verify.sh
  24_decompose.sh
  25_spawn.sh
  26_debate.sh
  27_mention_routing.sh
  28_model_switching.sh
)

# --- Main ---

main() {
  banner

  local total=${#SCRIPTS[@]}
  local passed=0
  local failed=0
  local failures=()

  for i in "${!SCRIPTS[@]}"; do
    local script="${SCRIPTS[$i]}"
    local index=$((i + 1))

    # Enable batch mode for scripts with interactive "your turn" sessions
    if printf '%s\n' "${BATCH_MODE_SCRIPTS[@]}" | grep -qx "${script}"; then
      export BATCH_MODE=true
    else
      unset BATCH_MODE
    fi

    if run_script "${script}" "${index}" "${total}"; then
      ((passed++))
    else
      ((failed++))
      failures+=("${script}")
    fi
  done

  unset BATCH_MODE

  echo "================================================================================"
  echo "  Summary"
  echo "================================================================================"
  echo
  echo "  Total:   ${total}"
  echo "  Passed:  ${passed}"
  echo "  Failed:  ${failed}"
  echo "  Skipped: ${#SKIPPED[@]}"
  echo

  if [[ ${failed} -gt 0 ]]; then
    echo "  Failed scripts:"
    printf '    - %s\n' "${failures[@]}"
    echo
  fi

  if [[ "${SAVE_OUTPUT}" == true ]]; then
    echo "  Output saved to: ${OUTPUT_FILE}"
    echo
  fi

  echo "  To compare against a future run:"
  echo "    diff output/run_PREV.log output/run_LATEST.log"
  echo
  echo "================================================================================"

  return ${failed}
}

# --- Execute ---

if [[ "${SAVE_OUTPUT}" == true ]]; then
  main 2>&1 | tee "${OUTPUT_FILE}"
  exit ${PIPESTATUS[0]}
else
  main
fi
