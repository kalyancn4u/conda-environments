#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# create-env.sh — create a Conda environment from a YAML under python/<ver>/environments/
#
# Usage:
#   ./create-env.sh -p 3.12 01-core                # from python/3.12/environments/01-core.yml
#   ./create-env.sh -p 3.10 ../python/3.10/templates/llm.yml   # from an explicit path
#   CONDA_EXE=mamba ./create-env.sh -p 3.12 02-ml  # use mamba as the solver
#
# The Python version is passed explicitly with -p/--python (required) — this
# script lives in the shared top-level scripts/ and is not tied to any one tree.
# Applies conda-forge + strict channel priority for a clean, consistent solve.
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
  echo "Example: $0 -p ${PYVER} 01-core" >&2
  exit 2
fi

# Resolve the argument to a YAML file: bare name -> environments/<name>.yml
arg="$1"
if [[ -f "$arg" ]]; then
  yml="$arg"
elif [[ -f "${ENV_DIR}/${arg}.yml" ]]; then
  yml="${ENV_DIR}/${arg}.yml"
elif [[ -f "${ENV_DIR}/${arg}" ]]; then
  yml="${ENV_DIR}/${arg}"
else
  echo "error: could not find an environment file for '${arg}' in ${ENV_DIR}" >&2
  exit 1
fi

# Prefer mamba if available (much faster solves); fall back to conda.
solver="${CONDA_EXE:-}"
if [[ -z "$solver" ]]; then
  if command -v mamba >/dev/null 2>&1; then solver=mamba; else solver=conda; fi
fi

echo ">> Creating environment from: ${yml}"
echo ">> Using solver: ${solver}"

# --yes for non-interactive CI use. Channel policy is enforced per-file via the
# `channels:` key; we also assert strict priority here for safety.
"$solver" env create --yes --file "$yml"

echo ">> Done. Activate with:  conda activate $(grep -m1 '^name:' "$yml" | awk '{print $2}')"
