#!/usr/bin/env bash
# examples/04_erb_templating.sh
#
# Demonstrates ERB templating in prompts.
# By default, <%= expression %> is evaluated as Ruby and replaced
# with the result before the prompt is sent to the model. You can
# disable this with 'erb: false' in the YAML front matter.
#
# Prerequisites: Run 00_setup_aia.sh first.
# Usage: cd examples && bash 04_erb_templating.sh

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo "=== Demo 04: ERB Templating ==="
echo
echo "AIA processes <%= expression %> tags as Ruby (ERB) before"
echo "sending prompts to the model. This gives prompts access to"
echo "the full Ruby language."
echo

# --- Part 1: ERB processing ON (default) ---

echo "--- Part 1: ERB processing ON (default) ---"
echo
echo "The prompt file prompts_dir/erbinfo.md contains:"
echo "==="
cat prompts_dir/erbinfo.md
echo "==="
echo
echo "The <%= %> tags will be evaluated and replaced with real values."
echo
echo "Running: aia -c ${CONFIG} --no-output erbinfo"
echo

aia -c "${CONFIG}" --no-output erbinfo

echo
echo

# --- Part 2: ERB processing OFF via front matter ---

echo "--- Part 2: ERB processing OFF (erb: false) ---"
echo
echo "The prompt file prompts_dir/erbinfo_raw.md contains:"
echo "==="
cat prompts_dir/erbinfo_raw.md
echo "==="
echo
echo "With 'erb: false' in the front matter, the <%= %> tags"
echo "are sent to the model as literal text."
echo
echo "Running: aia -c ${CONFIG} --no-output erbinfo_raw"
echo

aia -c "${CONFIG}" --no-output erbinfo_raw
