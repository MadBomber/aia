#!/usr/bin/env bash
# examples/17_require_and_conditionals.sh
#
# Demonstrates two ERB power features:
#
# 1. --require (--rq) loads Ruby libraries so they are available
#    inside ERB expressions in prompts.
#
# 2. ERB control flow (<% if %> / <% elsif %> / <% else %>)
#    lets you conditionally include or exclude sections of a
#    prompt based on parameter values.
#
# Prerequisites: Run 00_setup_aia.sh first.
# Usage: cd examples && bash 17_require_and_conditionals.sh

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo "=== Demo 17: --require and Conditional ERB ==="
echo

# --- Part 1: --require to load a Ruby library ---

echo "--- Part 1: Using --require to load a Ruby library ---"
echo
echo "The --rq flag loads a Ruby gem so ERB tags can use it."
echo "Here we load 'json' to call JSON.pretty_generate inside"
echo "the prompt."
echo
echo "The prompt file prompts_dir/require_demo.md contains:"
echo "==="
cat prompts_dir/require_demo.md
echo "==="
echo
echo "Running: aia -c ${CONFIG} --no-output --rq json require_demo"
echo

aia -c "${CONFIG}" --no-output --rq json require_demo

echo
echo

# --- Part 2: Conditional prompt text with ERB ---

echo "--- Part 2: Conditional text with ERB and parameters ---"
echo
echo "ERB control flow tags (<% if %>) let you include different"
echo "prompt text depending on parameter values."
echo
echo "The prompt file prompts_dir/conditional.md contains:"
echo "==="
cat prompts_dir/conditional.md
echo "==="
echo
echo "The 'audience' parameter defaults to 'developer'."
echo "The ERB if/elsif/else block selects the matching section."
echo
echo "Running with default (developer):"
echo "  aia -c ${CONFIG} --no-output conditional"
echo

aia -c "${CONFIG}" --no-output conditional

echo
echo
echo "The same prompt could be run for a different audience by"
echo "entering 'manager' or 'child' when prompted interactively,"
echo "or by overriding the default in a pipeline."
