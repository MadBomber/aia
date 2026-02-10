#!/usr/bin/env bash
# examples/10_stdin_piping.sh
#
# Demonstrates piping input into aia via STDIN.
# The piped content is appended to the prompt text before it
# is sent to the model.
#
# Prerequisites: Run 00_setup_aia.sh first.
# Usage: cd examples && bash 10_stdin_piping.sh

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo "=== Demo 10: STDIN Piping ==="
echo
echo "You can pipe text into aia. The piped content is appended"
echo "to the prompt so the model can reference it."
echo

echo "The prompt file prompts_dir/analyze.md contains:"
echo "==="
cat prompts_dir/analyze.md
echo "==="
echo

# --- Part 1: Pipe a string ---

echo "--- Part 1: Pipe a string with echo ---"
echo
echo "Running: echo \"Ruby is ...\" | aia -c ${CONFIG} --no-output analyze"
echo

echo "Ruby is a dynamic, interpreted programming language focused on
simplicity and productivity. It was created by Yukihiro Matsumoto
in 1995. Ruby is known for its elegant syntax, strong
metaprogramming capabilities, and the Rails web framework that
helped popularize it worldwide." | aia -c "${CONFIG}" --no-output analyze

echo
echo

# --- Part 2: Pipe a command's output ---

echo "--- Part 2: Pipe a command's output ---"
echo
echo "Running: ls -la prompts_dir/ | aia -c ${CONFIG} --no-output analyze"
echo

ls -la prompts_dir/ | aia -c "${CONFIG}" --no-output analyze
