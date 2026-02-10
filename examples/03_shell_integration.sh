#!/usr/bin/env bash
# examples/03_shell_integration.sh
#
# Demonstrates shell integration in prompts.
# By default, $(command) is executed and replaced with its output
# before the prompt is sent to the model. You can disable this
# with 'shell: false' in the YAML front matter.
#
# Prerequisites: Run 00_setup_aia.sh first.
# Usage: cd examples && bash 03_shell_integration.sh

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo "=== Demo 03: Shell Integration ==="
echo
echo "AIA expands \$(command) and \$ENVAR in prompts before sending"
echo "them to the model. This lets prompts include live system data."
echo

# --- Part 1: shell expansion ON (default) ---

echo "--- Part 1: Shell expansion ON (default) ---"
echo
echo "The prompt file prompts_dir/sysinfo.md contains:"
echo "==="
cat prompts_dir/sysinfo.md
echo "==="
echo
echo "The \$(command) references will be replaced with real values."
echo
echo "Running: aia -c ${CONFIG} --no-output sysinfo"
echo

aia -c "${CONFIG}" --no-output sysinfo

echo
echo

# --- Part 2: shell expansion OFF via front matter ---

echo "--- Part 2: Shell expansion OFF (shell: false) ---"
echo
echo "The prompt file prompts_dir/sysinfo_raw.md contains:"
echo "==="
cat prompts_dir/sysinfo_raw.md
echo "==="
echo
echo "With 'shell: false' in the front matter, the \$(command)"
echo "references are sent to the model as literal text."
echo
echo "Running: aia -c ${CONFIG} --no-output sysinfo_raw"
echo

aia -c "${CONFIG}" --no-output sysinfo_raw
