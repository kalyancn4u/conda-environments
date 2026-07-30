#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# register-kernel.sh — expose a conda environment as a Jupyter kernel.
#
# The modular environments are separate on disk, but you often want ONE JupyterLab
# that can open notebooks against any of them. Registering each env as a named
# kernel does exactly that: launch Lab from your core env, then pick the kernel
# ("Python (py312-ml)", "Python (py312-dl)", …) per notebook.
#
# Usage:
#   ./register-kernel.sh py312-ml                    # display "Python (py312-ml)"
#   ./register-kernel.sh py312-ml "ML (py3.12)"      # custom display name
#   ./register-kernel.sh --remove py312-ml           # unregister
#   ./register-kernel.sh --list                      # show installed kernels
#
# Requires `ipykernel` IN the target env (01-core/04-web already have it via
# jupyterlab; leaner envs like 02-ml may not — the script installs it if missing).
# -----------------------------------------------------------------------------
set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }
have conda || { echo "error: conda not found on PATH" >&2; exit 1; }

if [[ "${1:-}" == "--list" ]]; then
  jupyter kernelspec list 2>/dev/null || conda run -n base jupyter kernelspec list
  exit 0
fi

if [[ "${1:-}" == "--remove" ]]; then
  name="${2:?usage: $0 --remove <env-name>}"
  echo ">> Removing kernel '${name}' ..."
  jupyter kernelspec remove -f "$name" 2>/dev/null \
    || conda run -n base jupyter kernelspec remove -f "$name"
  echo ">> Removed."
  exit 0
fi

env_name="${1:?usage: $0 <env-name> [display-name]}"
display="${2:-Python (${env_name})}"

# Confirm the env exists.
if ! conda env list | awk '{print $1}' | grep -qx "$env_name"; then
  echo "error: conda env '${env_name}' not found (see: conda env list)" >&2
  exit 1
fi

# Ensure ipykernel is present in the target env.
if ! conda run -n "$env_name" python -c "import ipykernel" >/dev/null 2>&1; then
  echo ">> ipykernel not in '${env_name}' — installing it (conda-forge) ..."
  solver="conda"; have mamba && solver="mamba"
  "$solver" install --yes -n "$env_name" -c conda-forge ipykernel
fi

echo ">> Registering kernel: name='${env_name}'  display='${display}'  (user scope)"
conda run -n "$env_name" python -m ipykernel install --user \
  --name "$env_name" --display-name "$display"

echo ">> Done. In JupyterLab, choose the '${display}' kernel."
echo "   List:   $0 --list"
echo "   Remove: $0 --remove ${env_name}"
