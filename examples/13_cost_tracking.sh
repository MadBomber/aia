#!/usr/bin/env bash
# examples/13_cost_tracking.sh
#
# Demonstrates the --cost flag, which displays per-model cost
# estimates alongside token usage. This is useful for comparing
# the price/performance of different providers.
#
# --cost implies --tokens, so you do not need both flags.
#
# This demo uses two inexpensive cloud models:
#   - gpt-4o-mini (OpenAI)
#   - claude-haiku-4-5 (Anthropic)
#
# Prerequisites:
#   - Run 00_setup_aia.sh first
#   - Set OPENAI_API_KEY and ANTHROPIC_API_KEY in your environment
# Usage: cd examples && bash 13_cost_tracking.sh

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

MODEL_A="gpt-4o-mini"
MODEL_B="claude-haiku-4-5"

echo "=== Demo 13: Cost Tracking ==="
echo
echo "The --cost flag shows token usage AND estimated cost for"
echo "each model. With multiple models you get a side-by-side"
echo "cost comparison table with totals."
echo
echo "  Models: ${MODEL_A} (OpenAI), ${MODEL_B} (Anthropic)"
echo

# --- Check API keys ---

missing_keys=()
if [ -z "${OPENAI_API_KEY:-}" ]; then
  missing_keys+=("OPENAI_API_KEY")
fi
if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  missing_keys+=("ANTHROPIC_API_KEY")
fi

if [ ${#missing_keys[@]} -gt 0 ]; then
  echo "ERROR: The following API keys are not set:"
  for key in "${missing_keys[@]}"; do
    echo "  - ${key}"
  done
  echo
  echo "Export them before running this demo:"
  for key in "${missing_keys[@]}"; do
    echo "  export ${key}=your-key-here"
  done
  exit 1
fi

echo "The prompt file prompts_dir/whats_new.md contains:"
echo "==="
cat prompts_dir/whats_new.md
echo "==="
echo

# --- Run with --cost ---

echo "Running: aia -c ${CONFIG} --no-output --cost -m ${MODEL_A},${MODEL_B} whats_new"
echo

aia -c "${CONFIG}" --no-output --cost -m "${MODEL_A},${MODEL_B}" whats_new
