#!/usr/bin/env bash
# examples/15_parameters.sh
#
# Demonstrates prompt parameters defined in YAML front matter.
# Parameters let you create reusable prompt templates with
# placeholders that are filled in at runtime.
#
# In the front matter:
#   parameters:
#     name: World       # has a default value
#     language:          # null = required, user will be prompted
#
# In the prompt body, reference parameters with ERB:
#   Hello <%= name %>, welcome to <%= language %>!
#
# When a parameter has a default, AIA uses it automatically.
# When a parameter is null (no default), AIA prompts the user
# to enter a value interactively.
#
# Prerequisites: Run 00_setup_aia.sh first.
# Usage: cd examples && bash 15_parameters.sh

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo "=== Demo 15: Prompt Parameters ==="
echo
echo "Parameters make prompts reusable. Define them in the front"
echo "matter with default values, then reference them in the"
echo "prompt body with ERB tags like <%= name %>."
echo

# --- Part 1: All parameters have defaults ---

echo "--- Part 1: All defaults provided ---"
echo
echo "The prompt file prompts_dir/greeting.md contains:"
echo "==="
cat prompts_dir/greeting.md
echo "==="
echo
echo "All three parameters (name, language, tone) have defaults,"
echo "so AIA fills them in automatically with no user interaction."
echo
echo "Running: aia -c ${CONFIG} --no-output greeting"
echo

aia -c "${CONFIG}" --no-output greeting

echo
echo

# --- Part 2: A required parameter (interactive) ---

echo "--- Part 2: Required parameter (null default) ---"
echo
echo "The prompt file prompts_dir/greeting_required.md contains:"
echo "==="
cat prompts_dir/greeting_required.md
echo "==="
echo
echo "The 'name' parameter has no default (null), so AIA will"
echo "prompt you to enter a value. 'language' defaults to Spanish."
echo
echo "Running: aia -c ${CONFIG} --no-output greeting_required"
echo

aia -c "${CONFIG}" --no-output greeting_required
