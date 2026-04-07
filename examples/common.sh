# examples/common.sh
#
# Shared setup for all demo scripts. Source this at the top:
#   source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
#
# What it does:
#   1. cd's into the examples directory
#   2. Unsets all AIA_* environment variables so only the
#      config file controls behavior
#   3. Sets CONFIG for use in aia commands

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# When running from inside the development repo, prefer the local bin/aia
# over any system-installed gem. bin/aia loads from ../lib/aia directly,
# so demos always run against the version in this checkout.
# Exported so child processes (including `expect`'s `spawn aia`) inherit it.
REPO_BIN="$(cd "${SCRIPT_DIR}/.." && pwd)/bin"
if [ -f "${REPO_BIN}/aia" ]; then
  export PATH="${REPO_BIN}:${PATH}"
fi

# Clear all AIA_* env vars so personal settings don't leak in.
while IFS= read -r var; do
  unset "$var"
done < <(env | grep '^AIA_' | cut -d= -f1)

CONFIG="aia_config.yml"

# Drain leaked escape sequences from the terminal input buffer.
# Reline queries cursor position (\e[6n) inside the pty; the
# terminal's responses (\e[row;colR) can leak into bash's stdin
# after expect exits. Call this after every expect block.
drain_terminal() {
    sleep 0.2
    stty sane 2>/dev/null || true
    while IFS= read -r -t 0.2 -n 100 _ 2>/dev/null; do :; done
}
