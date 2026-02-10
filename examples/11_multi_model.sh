#!/usr/bin/env bash
# examples/11_multi_model.sh
#
# Demonstrates using multiple models in a single prompt.
#
# Comparison mode (default):
#   Each model answers independently and both responses are shown
#   side by side, prefixed with "from: model_name".
#
# Cooperative (consensus) mode:
#   Each model answers independently, then the first model
#   synthesizes a unified response from all answers.
#
# Multiple models are specified as a comma-separated list with -m.
# This demo uses two Ollama models. If you only have one model
# available, pull a second one first:
#   ollama pull phi4-mini
#
# Prerequisites: Run 00_setup_aia.sh first, plus a second model.
# Usage: cd examples && bash 11_multi_model.sh

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

MODEL_A="ollama/qwen3"
MODEL_B="ollama/phi4-mini"

echo "=== Demo 11: Multiple Models ==="
echo
echo "AIA can send the same prompt to multiple models at once."
echo "Specify models as a comma-separated list with -m."
echo
echo "  Comparison mode (default): show each model's response"
echo "  Cooperative mode (--consensus): synthesize a unified answer"
echo

echo "The prompt file prompts_dir/explain_recursion.md contains:"
echo "==="
cat prompts_dir/explain_recursion.md
echo "==="
echo

# --- Check that the second model is available ---

if ! ollama list 2>/dev/null | grep -q "^phi4-mini"; then
  echo "Model phi4-mini is not available. Pulling it now ..."
  ollama pull phi4-mini
  echo
fi

# --- Part 1: Comparison mode ---

echo "--- Part 1: Comparison mode (default) ---"
echo
echo "Each model answers independently. Both responses are shown."
echo
echo "Running: aia -c ${CONFIG} --no-output -m ${MODEL_A},${MODEL_B} explain_recursion"
echo

aia -c "${CONFIG}" --no-output -m "${MODEL_A},${MODEL_B}" explain_recursion

echo
echo

# --- Part 2: Cooperative (consensus) mode ---

echo "--- Part 2: Cooperative mode (--consensus) ---"
echo
echo "Both models answer, then ${MODEL_A} synthesizes a single"
echo "unified response from both answers."
echo
echo "Running: aia -c ${CONFIG} --no-output --consensus -m ${MODEL_A},${MODEL_B} explain_recursion"
echo

aia -c "${CONFIG}" --no-output --consensus -m "${MODEL_A},${MODEL_B}" explain_recursion
