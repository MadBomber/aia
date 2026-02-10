#!/usr/bin/env bash
# examples/06_prompt_chaining.sh
#
# Demonstrates prompt chaining with --next and the 'next:' front
# matter key. The first prompt's response becomes context for
# the second prompt.
#
# Prerequisites: Run 00_setup_aia.sh first.
# Usage: cd examples && bash 06_prompt_chaining.sh

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo "=== Demo 06: Prompt Chaining ==="
echo
echo "AIA can chain prompts so the output of the first becomes"
echo "context for the second. Two ways to do this:"
echo "  1. CLI:        --next prompt_id"
echo "  2. Front matter: next: prompt_id"
echo

# --- Part 1: --next via CLI ---

echo "--- Part 1: Chaining with --next CLI flag ---"
echo
echo "The prompt file prompts_dir/tell_joke.md contains:"
echo "==="
cat prompts_dir/tell_joke.md
echo "==="
echo
echo "The prompt file prompts_dir/explain_joke.md contains:"
echo "==="
cat prompts_dir/explain_joke.md
echo "==="
echo
echo "Running: aia -c ${CONFIG} --no-output --next explain_joke tell_joke"
echo

aia -c "${CONFIG}" --no-output --next explain_joke tell_joke

echo
echo

# --- Part 2: next: in front matter ---

echo "--- Part 2: Chaining with 'next:' in front matter ---"
echo
echo "The prompt file prompts_dir/tell_joke_with_next.md contains:"
echo "==="
cat prompts_dir/tell_joke_with_next.md
echo "==="
echo
echo "The 'next: explain_joke' front matter does the same thing"
echo "as --next but is embedded in the prompt file itself."
echo
echo "Running: aia -c ${CONFIG} --no-output tell_joke_with_next"
echo

aia -c "${CONFIG}" --no-output tell_joke_with_next
