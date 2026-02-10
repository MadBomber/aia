#!/usr/bin/env bash
# examples/08_context_files.sh
#
# Demonstrates the --context-files option, which attaches the
# contents of one or more files to the prompt so the model can
# reference them in its response.
#
# Context files are listed as positional arguments after the
# prompt ID:
#   aia PROMPT_ID FILE1 FILE2 ...
#
# Prerequisites: Run 00_setup_aia.sh first.
# Usage: cd examples && bash 08_context_files.sh

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo "=== Demo 08: Context Files ==="
echo
echo "Context files let you attach file contents to a prompt so"
echo "the model can read and reference them. List the files after"
echo "the prompt ID on the command line."
echo

echo "The prompt file prompts_dir/summarize_context.md contains:"
echo "==="
cat prompts_dir/summarize_context.md
echo "==="
echo

echo "We will attach two context files:"
echo
echo "--- context/project_goals.md ---"
cat context/project_goals.md
echo
echo "--- context/tech_stack.md ---"
cat context/tech_stack.md
echo

echo "Running: aia -c ${CONFIG} --no-output summarize_context context/project_goals.md context/tech_stack.md"
echo

aia -c "${CONFIG}" --no-output summarize_context context/project_goals.md context/tech_stack.md
