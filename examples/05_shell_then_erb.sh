#!/usr/bin/env bash
# examples/05_shell_then_erb.sh
#
# Demonstrates that shell expansion runs BEFORE ERB processing.
# This means $(command) and $ENVAR are replaced with their values
# first, and then ERB evaluates the result as Ruby.
#
# This ordering lets you use shell output inside Ruby expressions.
#
# Prerequisites: Run 00_setup_aia.sh first.
# Usage: cd examples && bash 05_shell_then_erb.sh

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo "=== Demo 05: Shell Runs Before ERB ==="
echo
echo "AIA processes prompts in this order:"
echo "  1. Shell: \$(command) and \$ENVAR are expanded"
echo "  2. ERB:  <%= expression %> is evaluated as Ruby"
echo
echo "This means shell output becomes part of the Ruby expression"
echo "that ERB then evaluates."
echo
echo "The prompt file prompts_dir/shell_then_erb.md contains:"
echo "==="
cat prompts_dir/shell_then_erb.md
echo "==="
echo
echo "For example:"
echo "  <%= \"\$(uname -s)\".downcase %>"
echo "  Step 1 (shell): <%= \"Darwin\".downcase %>"
echo "  Step 2 (ERB):   darwin"
echo
echo "Running: aia -c ${CONFIG} --no-output shell_then_erb"
echo

aia -c "${CONFIG}" --no-output shell_then_erb
