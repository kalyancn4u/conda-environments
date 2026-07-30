#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# setup-venv.sh — create a venv and install a pinned requirements set into it.
#
# This is the PyPI/production counterpart to create-env.sh (which builds conda
# environments). It builds a slim, Python-only virtual environment from the
# repo's pinned `lockfiles/requirements/*.txt` — the artifact CI/CD deploys.
#
# Usage:
#   ./setup-venv.sh 04-web                 # -> lockfiles/requirements/04-web.txt into ./.venv
#   ./setup-venv.sh 04-web .venv-web       # custom venv directory
#   ./setup-venv.sh path/to/requirements.txt
#   ./setup-venv.sh 04-web --system        # container mode: install into system python, no venv
#
# It prefers `uv` (fast; also creates the venv) and falls back to `python -m venv`
# + `pip`. It ALWAYS targets the venv's own interpreter explicitly, so it can
# never accidentally install into an active conda environment.
#
# Version-agnostic: resolves the requirements dir from its own path (3.10 / 3.12).
# -----------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VER_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"          # python/<ver>
REQ_DIR="${VER_ROOT}/lockfiles/requirements"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <req-name|path-to-requirements.txt> [venv-dir|--system]" >&2
  echo "Example: $0 04-web            (installs 04-web.txt into ./.venv)" >&2
  exit 2
fi

# --- Resolve the requirements file -----------------------------------------
arg="$1"; shift || true
if [[ -f "$arg" ]]; then
  req="$arg"
elif [[ -f "${REQ_DIR}/${arg}.txt" ]]; then
  req="${REQ_DIR}/${arg}.txt"
elif [[ -f "${REQ_DIR}/${arg}" ]]; then
  req="${REQ_DIR}/${arg}"
else
  echo "error: could not find a requirements file for '${arg}'" >&2
  echo "       looked in ${REQ_DIR}/ and as a literal path" >&2
  exit 1
fi

# --- Second arg: venv dir, or --system (container) mode ---------------------
venv_dir=".venv"
system_mode=0
if [[ "${1:-}" == "--system" ]]; then
  system_mode=1
elif [[ $# -ge 1 ]]; then
  venv_dir="$1"
fi

# --- Safety: warn if a named conda env is active ---------------------------
# We install into the venv explicitly regardless, but an active conda env is a
# smell (docs/conda-vs-uv.md §5). --system inside such a shell is genuinely risky.
if [[ -n "${CONDA_PREFIX:-}" && "${CONDA_DEFAULT_ENV:-base}" != "base" ]]; then
  echo ">> WARNING: conda env '${CONDA_DEFAULT_ENV}' is active." >&2
  if [[ $system_mode -eq 1 ]]; then
    echo "   --system would install into the conda env. Run 'conda deactivate' first." >&2
    exit 1
  fi
  echo "   Proceeding, but installing into a dedicated venv (never the conda env)." >&2
fi

have() { command -v "$1" >/dev/null 2>&1; }

echo ">> Requirements: ${req}"

if [[ $system_mode -eq 1 ]]; then
  # Container / CI mode: the container is the isolation, so no venv is needed.
  echo ">> Mode: --system (installing into the current interpreter)"
  if have uv; then
    uv pip install --system --no-cache -r "$req"
  else
    python -m pip install --no-cache-dir -r "$req"
  fi
  echo ">> Done (system install)."
  exit 0
fi

# --- venv mode --------------------------------------------------------------
if have uv; then
  echo ">> Creating venv with uv at: ${venv_dir}"
  uv venv "$venv_dir"
else
  echo ">> uv not found; creating venv with python -m venv at: ${venv_dir}"
  python -m venv "$venv_dir"
fi

# Locate the venv interpreter cross-platform (POSIX: bin/, Windows/Git-Bash: Scripts/).
if [[ -x "${venv_dir}/bin/python" ]]; then
  vpy="${venv_dir}/bin/python"
  activate="source ${venv_dir}/bin/activate"
elif [[ -x "${venv_dir}/Scripts/python.exe" ]]; then
  vpy="${venv_dir}/Scripts/python.exe"
  activate="${venv_dir}\\Scripts\\activate"
else
  echo "error: could not find the venv interpreter under ${venv_dir}" >&2
  exit 1
fi

echo ">> Installing into: ${vpy}"
if have uv; then
  # --python pins the target explicitly; uv can never reach an active conda env.
  uv pip install --python "$vpy" -r "$req"
else
  "$vpy" -m pip install --upgrade pip >/dev/null
  "$vpy" -m pip install -r "$req"
fi

echo ">> Done. Activate with:"
echo "     ${activate}"
