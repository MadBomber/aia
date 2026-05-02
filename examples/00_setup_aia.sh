#!/usr/bin/env bash
# examples/00_setup_aia.sh
#
# Sets up the environment for running AIA example demos.
# Run this script first before any other example script.
#
# What it does:
#   1. Verifies aia is installed
#   2. Verifies OPENAI_API_KEY is set
#   3. Verifies examples/prompts_dir exists
#   4. Writes examples/aia_config.yml for use with -c flag
#
# Each demo script sources common.sh which clears AIA_* env vars
# and sets CONFIG=aia_config.yml for clean, isolated runs.
#
# Usage:
#   cd examples
#   bash 00_setup_aia.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPTS_DIR="${SCRIPT_DIR}/prompts_dir"
CONFIG_FILE="${SCRIPT_DIR}/aia_config.yml"

# When running from inside the development repo, prefer the local bin/aia
# over any system-installed gem so setup reflects the version being demoed.
REPO_BIN="$(cd "${SCRIPT_DIR}/.." && pwd)/bin"
if [ -f "${REPO_BIN}/aia" ]; then
  export PATH="${REPO_BIN}:${PATH}"
fi

# The model to use for demos. gpt-4.1 is OpenAI's flagship model with
# strong instruction-following and tool-calling support.
DEMO_MODEL="gpt-4.1"

echo "=== AIA Examples Setup ==="
echo

# --- Step 1: Check that aia is installed ---

if ! command -v aia &> /dev/null; then
  echo "ERROR: 'aia' is not found."
  echo "       From the repo:  just install   (installs local build)"
  echo "       From RubyGems:  gem install aia"
  exit 1
fi

AIA_VERSION=$(aia --version 2>/dev/null || echo "unknown")
echo "[ok] aia is installed (v${AIA_VERSION})"

# --- Step 2: Check that OPENAI_API_KEY is set ---

if [ -z "${OPENAI_API_KEY:-}" ]; then
  echo "ERROR: OPENAI_API_KEY is not set."
  echo "       Export your key before running demos:"
  echo "         export OPENAI_API_KEY=sk-..."
  echo "       Get a key at: https://platform.openai.com/api-keys"
  exit 1
fi

echo "[ok] OPENAI_API_KEY is set"

# --- Step 3: Verify prompts directory ---

echo
if [ -d "${PROMPTS_DIR}" ]; then
  echo "[ok] prompts_dir exists at ${PROMPTS_DIR}"
else
  mkdir -p "${PROMPTS_DIR}"
  echo "[ok] created prompts_dir at ${PROMPTS_DIR}"
fi

# --- Step 4: Write the config file ---

cat > "${CONFIG_FILE}" <<EOF
# AIA configuration for example demos
# Used by all demo scripts via: aia -c aia_config.yml ...
#
# This file is loaded with the -c / --config-file flag.
# It replaces the user's personal config (~/.config/aia/aia.yml),
# starting from bundled defaults + these values only.
# CLI flags passed directly to aia still take precedence.
#
# NOTE: Relative paths resolve against the directory where aia is invoked.
#       Run demo scripts from the examples/ directory.

prompts:
  dir: ./prompts_dir

models:
  - name: ${DEMO_MODEL}

output:
  file: ~

flags:
  chat: false
EOF

echo "[ok] wrote ${CONFIG_FILE}"

# --- Done ---

echo
echo "=== Setup Complete ==="
echo
echo "All demo scripts use:"
echo "  aia -c aia_config.yml ..."
echo "  Model:       ${DEMO_MODEL}"
echo "  Prompts dir: ${PROMPTS_DIR}"
