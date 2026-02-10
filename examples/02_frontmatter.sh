#!/usr/bin/env bash
# examples/02_frontmatter.sh
#
# Demonstrates YAML front matter in prompt files.
# Front matter lets you embed configuration directly in the prompt,
# such as temperature, model, top_p, and more.
#
# Prerequisites: Run 00_setup_aia.sh first.
# Usage: cd examples && bash 02_frontmatter.sh

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo "=== Demo 02: YAML Front Matter ==="
echo
echo "Prompt files can include a YAML front matter block between"
echo "--- delimiters. AIA applies these settings before sending"
echo "the prompt to the model."
echo
echo "Supported root-level shorthands:"
echo "  model, temperature, top_p, next, pipeline, shell, erb"
echo
echo "The prompt file prompts_dir/creative.md contains:"
echo "==="
cat prompts_dir/creative.md
echo "==="
echo
echo "The 'temperature: 0.9' setting makes the response more creative."
echo
echo "Running: aia -c ${CONFIG} --no-output creative"
echo

aia -c "${CONFIG}" --no-output creative
