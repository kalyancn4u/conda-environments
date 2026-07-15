#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# update-env.sh — update an existing environment to match its YAML definition
#
# Usage:
#   ./update-env.sh 01-core
#
# Uses `--prune` so packages removed from the YAML are also removed from the env,
# keeping the environment an exact reflection of its definition.
# -----------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_DIR="${SCRIPT_DIR}/../environments"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <env-name|path-to-yml>" >&2
  exit 2
fi

arg="$1"
if [[ -f "$arg" ]]; then yml="$arg"
elif [[ -f "${ENV_DIR}/${arg}.yml" ]]; then yml="${ENV_DIR}/${arg}.yml"
else echo "error: environment file for '${arg}' not found" >&2; exit 1
fi

solver="${CONDA_EXE:-}"
if [[ -z "$solver" ]]; then
  if command -v mamba >/dev/null 2>&1; then solver=mamba; else solver=conda; fi
fi

echo ">> Updating environment from: ${yml} (with --prune)"
"$solver" env update --file "$yml" --prune
echo ">> Update complete."
