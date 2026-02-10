#!/usr/bin/env bash
# examples/09_roles.sh
#
# Demonstrates the --role option, which prepends a role prompt
# to the main prompt. Roles live as .md files in the roles/
# subdirectory under the prompts directory.
#
# Prerequisites: Run 00_setup_aia.sh first.
# Usage: cd examples && bash 09_roles.sh

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo "=== Demo 09: Roles ==="
echo
echo "Roles are reusable system prompts stored as .md files in"
echo "the roles/ subdirectory of your prompts directory. Use"
echo "--role ROLE_ID to prepend a role to any prompt."
echo

echo "The prompt file prompts_dir/weather.md contains:"
echo "==="
cat prompts_dir/weather.md
echo "==="
echo

echo "Available roles:"
echo
for role in prompts_dir/roles/*.md; do
  name=$(basename "$role" .md)
  echo "--- roles/${name}.md ---"
  cat "$role"
done
echo

# --- Part 1: No role (baseline) ---

echo "--- Part 1: No role (baseline) ---"
echo
echo "Running: aia -c ${CONFIG} --no-output weather"
echo

aia -c "${CONFIG}" --no-output weather

echo
echo

# --- Part 2: Pirate role ---

echo "--- Part 2: With --role pirate ---"
echo
echo "Running: aia -c ${CONFIG} --no-output --role pirate weather"
echo

aia -c "${CONFIG}" --no-output --role pirate weather

echo
echo

# --- Part 3: Formal butler role ---

echo "--- Part 3: With --role formal ---"
echo
echo "Running: aia -c ${CONFIG} --no-output --role formal weather"
echo

aia -c "${CONFIG}" --no-output --role formal weather
