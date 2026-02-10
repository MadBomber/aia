#!/usr/bin/env bash
# examples/21_executable_prompts.sh
#
# Demonstrates executable prompt files — prompt files with a shebang
# line that can be run directly from the command line.
#
# AIA auto-detects the shebang (#!) and strips it before processing.
# No special flag is needed. Just add a shebang, chmod +x, and run.
#
# Three ways to use an executable prompt:
#   1. Run directly:        ./prompts_dir/fun_fact
#   2. Pass to aia:         aia prompts_dir/fun_fact
#   3. Pipe to aia:         cat prompts_dir/fun_fact | aia --no-output
#
# Prerequisites:
#   - Run 00_setup_aia.sh first
# Usage: cd examples && bash 21_executable_prompts.sh

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo "=== Demo 21: Executable Prompts ==="
echo
echo "Executable prompts are prompt files with a shebang line."
echo "AIA auto-detects the shebang, strips it, and processes"
echo "the rest as a normal prompt — front matter, ERB, and all."
echo

# --- Part 1: A minimal executable prompt ---

echo "--- Part 1: Minimal executable prompt ---"
echo
echo "The file prompts_dir/fun_fact contains:"
echo "==="
cat prompts_dir/fun_fact
echo "==="
echo
echo "It has the executable bit set (chmod +x)."
echo "Running it directly: ./prompts_dir/fun_fact"
echo

./prompts_dir/fun_fact

echo
echo

# --- Part 2: Executable prompt with front matter, ERB, and shell ---

echo "--- Part 2: Executable prompt with front matter, ERB, and shell ---"
echo
echo "The file prompts_dir/project_summary contains:"
echo "==="
cat prompts_dir/project_summary
echo "==="
echo
echo "This prompt combines a shebang, YAML front matter (temperature),"
echo "ERB (<%= ... %>), and shell expansion (\$(...)). All three"
echo "processing layers work inside executable prompts."
echo
echo "Running: ./prompts_dir/project_summary"
echo

./prompts_dir/project_summary

echo
echo

# --- Part 3: Piping an executable prompt file ---

echo "--- Part 3: Piping a prompt file to AIA ---"
echo
echo "Any prompt file — even one with a shebang — can be piped to AIA."
echo "The shebang line is automatically stripped from piped input."
echo
echo "Running: cat prompts_dir/fun_fact | aia -c ${CONFIG} --no-output"
echo

cat prompts_dir/fun_fact | aia -c "${CONFIG}" --no-output
