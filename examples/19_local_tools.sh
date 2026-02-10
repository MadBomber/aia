#!/usr/bin/env bash
# examples/19_local_tools.sh
#
# Demonstrates loading a local RubyLLM::Tool from a file using
# the --tools option. Unlike --require (which loads gems), --tools
# loads .rb files directly from a path. You can pass a single file
# or a directory (all .rb files in it will be loaded).
#
# Prerequisites: Run 00_setup_aia.sh first.
# Usage: cd examples && bash 19_local_tools.sh

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo "=== Demo 19: Local Tools ==="
echo
echo "The --tools flag loads RubyLLM::Tool subclasses from local"
echo ".rb files. Pass a file path or a directory."
echo

echo "The tool file tools/word_count_tool.rb defines:"
echo "==="
cat tools/word_count_tool.rb
echo "==="
echo
echo "The prompt file prompts_dir/use_local_tool.md contains:"
echo "==="
cat prompts_dir/use_local_tool.md
echo "==="
echo
echo "Running: aia -c ${CONFIG} --no-output --tools tools/word_count_tool.rb use_local_tool"
echo

aia -c "${CONFIG}" --no-output --tools tools/word_count_tool.rb use_local_tool
