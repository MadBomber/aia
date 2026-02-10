#!/usr/bin/env bash
# examples/12_token_usage.sh
#
# Demonstrates the --tokens flag, which displays token usage
# after each response. When used with multiple models this lets
# you compare how verbose each model is.
#
# Prerequisites: Run 00_setup_aia.sh first, plus a second model.
#   ollama pull phi4-mini
# Usage: cd examples && bash 12_token_usage.sh

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

MODEL_A="ollama/qwen3"
MODEL_B="ollama/phi4-mini"

echo "=== Demo 12: Token Usage ==="
echo
echo "The --tokens flag shows input and output token counts after"
echo "each response. This is useful for monitoring usage and"
echo "comparing verbosity across models."
echo

echo "The prompt file prompts_dir/sort_compare.md contains:"
echo "==="
cat prompts_dir/sort_compare.md
echo "==="
echo

# --- Check that the second model is available ---

if ! ollama list 2>/dev/null | grep -q "^phi4-mini"; then
  echo "Model phi4-mini is not available. Pulling it now ..."
  ollama pull phi4-mini
  echo
fi

# --- Part 1: Single model with --tokens ---

echo "--- Part 1: Single model with --tokens ---"
echo
echo "Running: aia -c ${CONFIG} --no-output --tokens sort_compare"
echo

aia -c "${CONFIG}" --no-output --tokens sort_compare

echo
echo

# --- Part 2: Multiple models with --tokens ---

echo "--- Part 2: Multiple models with --tokens ---"
echo
echo "With multiple models, token counts are shown for each model"
echo "so you can compare their usage side by side."
echo
echo "Running: aia -c ${CONFIG} --no-output --tokens -m ${MODEL_A},${MODEL_B} sort_compare"
echo

aia -c "${CONFIG}" --no-output --tokens -m "${MODEL_A},${MODEL_B}" sort_compare
