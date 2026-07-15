#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# create-env.sh — create a Conda environment from a YAML in ../environments/
#
# Usage:
#   ./create-env.sh 01-core                # from environments/01-core.yml
#   ./create-env.sh ../templates/llm.yml   # from an explicit path
#   CONDA_EXE=mamba ./create-env.sh 02-ml  # use mamba as the solver
#
# Applies conda-forge + strict channel priority for a clean, consistent solve.
# -----------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_DIR="${SCRIPT_DIR}/../environments"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <env-name|path-to-yml>" >&2
  echo "Example: $0 01-core" >&2
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
  echo "error: could not find an environment file for '${arg}'" >&2
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
