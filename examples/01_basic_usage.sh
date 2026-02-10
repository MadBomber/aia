#!/usr/bin/env bash
# examples/01_basic_usage.sh
#
# Demonstrates the simplest use of aia: sending a prompt to a model
# and printing the response.
#
# Prerequisites: Run 00_setup_aia.sh first.
# Usage: cd examples && bash 01_basic_usage.sh

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo "=== Demo 01: Basic Usage ==="
echo
echo "The prompt file prompts_dir/hello.md contains:"
echo "==="
cat prompts_dir/hello.md
echo "==="
echo
echo "Running: aia -c ${CONFIG} --no-output hello"
echo

aia -c "${CONFIG}" --no-output hello
