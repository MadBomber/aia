#!/usr/bin/env bash
# examples/14_output_file.sh
#
# Demonstrates the -o / --output option for saving responses
# to a file. Also shows --append for accumulating multiple
# responses in the same file.
#
# Options:
#   -o FILE         Write response to FILE (overwrites)
#   -o              Write response to temp.md (default name)
#   --no-output     Do not write to any file
#   -a / --append   Append instead of overwriting
#
# Prerequisites: Run 00_setup_aia.sh first.
# Usage: cd examples && bash 14_output_file.sh

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

OUTPUT_FILE="demo_output.md"

# Clean up from previous runs
rm -f "${OUTPUT_FILE}"

echo "=== Demo 14: Output to File ==="
echo
echo "The -o flag saves the model's response to a file."
echo "By default, each run overwrites the file. Use --append"
echo "to accumulate responses."
echo

echo "The prompt file prompts_dir/limerick.md contains:"
echo "==="
cat prompts_dir/limerick.md
echo "==="
echo

# --- Part 1: Write to a file ---

echo "--- Part 1: Save response to a file ---"
echo
echo "Running: aia -c ${CONFIG} -o ${OUTPUT_FILE} limerick"
echo

aia -c "${CONFIG}" -o "${OUTPUT_FILE}" limerick

echo
echo "Contents of ${OUTPUT_FILE}:"
echo "==="
cat "${OUTPUT_FILE}"
echo "==="
echo

# --- Part 2: Overwrite with a second run ---

echo "--- Part 2: Overwrite (default behavior) ---"
echo
echo "Running the same command again overwrites the file."
echo
echo "Running: aia -c ${CONFIG} -o ${OUTPUT_FILE} limerick"
echo

aia -c "${CONFIG}" -o "${OUTPUT_FILE}" limerick

echo
echo "Contents of ${OUTPUT_FILE} (new response replaced the old one):"
echo "==="
cat "${OUTPUT_FILE}"
echo "==="
echo

# --- Part 3: Append mode ---

echo "--- Part 3: Append mode (--append) ---"
echo
echo "With --append, responses are added to the end of the file"
echo "instead of replacing it."
echo
echo "Running: aia -c ${CONFIG} -o ${OUTPUT_FILE} --append limerick"
echo

aia -c "${CONFIG}" -o "${OUTPUT_FILE}" --append limerick

echo
echo "Contents of ${OUTPUT_FILE} (now has two responses):"
echo "==="
cat "${OUTPUT_FILE}"
echo "==="

# Clean up
rm -f "${OUTPUT_FILE}"
