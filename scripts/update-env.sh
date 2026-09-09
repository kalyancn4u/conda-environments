#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# update-env.sh — update an existing environment to match its YAML definition
#
# Usage:
#   ./update-env.sh -p 3.12 01-core
#
# The Python version is passed explicitly with -p/--python (required).
# Uses `--prune` so packages removed from the YAML are also removed from the env,
# keeping the environment an exact reflection of its definition.
# -----------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# --- explicit Python version (required): -p/--python <X.Y> -------------------
PYVER=""
args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--python) PYVER="${2:-}"; shift 2 ;;
    -p=*|--python=*) PYVER="${1#*=}"; shift ;;
    *) args+=("$1"); shift ;;
  esac
done
set -- "${args[@]:-}"
if [[ -z "$PYVER" ]]; then
  echo "error: -p/--python <X.Y> is required (e.g. -p 3.12)" >&2
  echo "Usage: $0 -p <X.Y> <env-name|path-to-yml>" >&2
  exit 2
fi
VER_ROOT="${REPO_ROOT}/python/${PYVER}"
ENV_DIR="${VER_ROOT}/environments"
if [[ ! -d "$VER_ROOT" ]]; then
  echo "error: no such Python tree: python/${PYVER} (expected ${VER_ROOT})" >&2
  exit 1
fi

if [[ $# -lt 1 || -z "${1:-}" ]]; then
  echo "Usage: $0 -p <X.Y> <env-name|path-to-yml>" >&2
  exit 2
fi

arg="$1"
if [[ -f "$arg" ]]; then yml="$arg"
elif [[ -f "${ENV_DIR}/${arg}.yml" ]]; then yml="${ENV_DIR}/${arg}.yml"
else echo "error: environment file for '${arg}' not found in ${ENV_DIR}" >&2; exit 1
fi

solver="${CONDA_EXE:-}"
if [[ -z "$solver" ]]; then
  if command -v mamba >/dev/null 2>&1; then solver=mamba; else solver=conda; fi
fi

echo ">> Updating environment from: ${yml} (with --prune)"
"$solver" env update --file "$yml" --prune
echo ">> Update complete."
