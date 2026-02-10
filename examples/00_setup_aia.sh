#!/usr/bin/env bash
# examples/00_setup_aia.sh
#
# Sets up the environment for running AIA example demos.
# Run this script first before any other example script.
#
# What it does:
#   1. Verifies aia is installed
#   2. Verifies ollama is installed and running
#   3. Pulls the qwen3 model (good tool-calling support)
#   4. Verifies examples/prompts_dir exists
#   5. Writes examples/aia_config.yml for use with -c flag
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

# The model to use for demos. qwen3 is Ollama's reference model
# for tool calling and has strong instruction-following ability.
DEMO_MODEL="qwen3"

echo "=== AIA Examples Setup ==="
echo

# --- Step 1: Check that aia is installed ---

if ! command -v aia &> /dev/null; then
  echo "ERROR: 'aia' is not installed."
  echo "       Install with: gem install aia"
  exit 1
fi

AIA_VERSION=$(aia --version 2>/dev/null || echo "unknown")
echo "[ok] aia is installed (v${AIA_VERSION})"

# --- Step 2: Check that ollama is installed and running ---

if ! command -v ollama &> /dev/null; then
  echo "ERROR: 'ollama' is not installed."
  echo "       Install from: https://ollama.com"
  echo "       macOS: brew install ollama"
  exit 1
fi

echo "[ok] ollama is installed"

# Check if ollama is serving
OLLAMA_BASE="${OLLAMA_API_BASE:-http://localhost:11434}"

if ! curl -s "${OLLAMA_BASE}/api/tags" > /dev/null 2>&1; then
  echo "WARNING: ollama does not appear to be running."
  echo "         Start it with: ollama serve"
  echo "         Then re-run this script."
  exit 1
fi

echo "[ok] ollama is running at ${OLLAMA_BASE}"

# --- Step 3: Pull the demo model ---

echo
echo "Checking for model: ${DEMO_MODEL} ..."

if ollama list 2>/dev/null | grep -q "^${DEMO_MODEL}"; then
  echo "[ok] ${DEMO_MODEL} is already available"
else
  echo "Pulling ${DEMO_MODEL} (this may take a few minutes on first run) ..."
  ollama pull "${DEMO_MODEL}"
  echo "[ok] ${DEMO_MODEL} pulled successfully"
fi

# --- Step 4: Verify prompts directory ---

echo
if [ -d "${PROMPTS_DIR}" ]; then
  echo "[ok] prompts_dir exists at ${PROMPTS_DIR}"
else
  mkdir -p "${PROMPTS_DIR}"
  echo "[ok] created prompts_dir at ${PROMPTS_DIR}"
fi

# --- Step 5: Write the config file ---

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
  - name: ollama/${DEMO_MODEL}

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
echo "  Model:       ollama/${DEMO_MODEL}"
echo "  Prompts dir: ${PROMPTS_DIR}"
