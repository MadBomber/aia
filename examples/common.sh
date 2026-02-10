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

# Clear all AIA_* env vars so personal settings don't leak in.
while IFS= read -r var; do
  unset "$var"
done < <(env | grep '^AIA_' | cut -d= -f1)

CONFIG="aia_config.yml"
