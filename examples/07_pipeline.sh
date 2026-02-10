#!/usr/bin/env bash
# examples/07_pipeline.sh
#
# Demonstrates a prompt pipeline — a sequence of prompts where
# each step's response becomes context for the next.
#
# The --pipeline flag accepts comma-separated prompt IDs.
# The first prompt ID is the main argument; the rest go in --pipeline.
#
# NOTE: The same chain could be embedded in the first prompt's
# front matter instead:
#   ---
#   pipeline: evaluate, pick_best, tagline
#   ---
#
# Prerequisites: Run 00_setup_aia.sh first.
# Usage: cd examples && bash 07_pipeline.sh

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo "=== Demo 07: Prompt Pipeline ==="
echo
echo "A pipeline chains multiple prompts in sequence. Each prompt's"
echo "response becomes context for the next. This is useful for"
echo "multi-step reasoning and refinement workflows."
echo
echo "This demo runs a 4-step pipeline:"
echo "  1. brainstorm   — generate five gem names"
echo "  2. evaluate     — rate each name 1-5"
echo "  3. pick_best    — choose the winner"
echo "  4. tagline      — write a tagline for it"
echo

echo "The prompt files:"
echo
for p in brainstorm evaluate pick_best tagline; do
  echo "--- prompts_dir/${p}.md ---"
  cat "prompts_dir/${p}.md"
done
echo

echo "Running: aia -c ${CONFIG} --no-output --pipeline evaluate,pick_best,tagline brainstorm"
echo

aia -c "${CONFIG}" --no-output --pipeline evaluate,pick_best,tagline brainstorm
