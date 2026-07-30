#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# micromamba-env.sh — create + verify an environment with ZERO prior install.
#
# For CI, Docker, and throwaway/automation use where you don't want a full conda
# install. If `micromamba` isn't on PATH, this downloads the ~30 MB static binary
# into a local, gitignored folder and uses it in place — nothing is installed
# system-wide, and the whole thing can be deleted afterward.
#
# Usage:
#   ./micromamba-env.sh 01-core              # env <pytag>-core from environments/01-core.yml, then verify
#   ./micromamba-env.sh ../templates/llm.yml # from an explicit path (no verify)
#   MAMBA_ROOT_PREFIX=./mm ./micromamba-env.sh 01-core   # custom root prefix
#
# Version-agnostic: resolves paths/env-name from its own location (3.10 / 3.12).
# -----------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VER_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"          # python/<ver>
PYVER="$(basename "$VER_ROOT")"                   # 3.12
PYTAG="py${PYVER//./}"                             # py312
ENV_DIR="${VER_ROOT}/environments"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <env-stem|path-to-yml>   e.g. $0 01-core" >&2
  exit 2
fi

# --- Resolve the YAML and, when it's a numbered env, the verify key ---------
arg="$1"; verify_key=""
if [[ -f "$arg" ]]; then
  yml="$arg"
elif [[ -f "${ENV_DIR}/${arg}.yml" ]]; then
  yml="${ENV_DIR}/${arg}.yml"
elif [[ -f "${ENV_DIR}/${arg}" ]]; then
  # script-relative path (e.g. ../templates/llm.yml), independent of CWD
  yml="${ENV_DIR}/${arg}"
else
  echo "error: could not find an environment file for '${arg}'" >&2
  exit 1
fi
# Map the numbered env stems to verify-env.py keys (same table as test-env.sh).
case "$(basename "$yml")" in
  01-core.yml)          verify_key=core ;;
  02-ml.yml)            verify_key=ml ;;
  03-deep-learning.yml) verify_key=dl ;;
  04-web.yml)           verify_key=web ;;
  05-tools.yml)         verify_key=tools ;;
  06-tensorflow.yml)    verify_key=tf ;;
  07-geospatial.yml)    verify_key=geo ;;
  08-timeseries.yml)    verify_key=ts ;;
esac

# The env name comes from the YAML's `name:` key (e.g. py312-core).
env_name="$(grep -m1 '^name:' "$yml" | awk '{print $2}')"
[[ -z "$env_name" ]] && env_name="${PYTAG}-adhoc"

# --- Ensure micromamba is available ----------------------------------------
MAMBA_ROOT_PREFIX="${MAMBA_ROOT_PREFIX:-${VER_ROOT}/.micromamba}"
export MAMBA_ROOT_PREFIX

if command -v micromamba >/dev/null 2>&1; then
  MM="micromamba"
else
  bindir="${MAMBA_ROOT_PREFIX}/bin"
  MM="${bindir}/micromamba"
  if [[ ! -x "$MM" ]]; then
    echo ">> micromamba not found — downloading a local copy into ${bindir}"
    mkdir -p "$bindir"
    # Detect platform for the release asset name.
    os="$(uname -s)"; arch="$(uname -m)"
    case "$os" in
      Linux)  case "$arch" in x86_64) plat=linux-64 ;; aarch64|arm64) plat=linux-aarch64 ;; *) echo "unsupported arch $arch" >&2; exit 1 ;; esac ;;
      Darwin) case "$arch" in arm64) plat=osx-arm64 ;; x86_64) plat=osx-64 ;; *) echo "unsupported arch $arch" >&2; exit 1 ;; esac ;;
      *) echo "unsupported OS '$os' — install micromamba manually, or use the .ps1 on Windows" >&2; exit 1 ;;
    esac
    url="https://github.com/mamba-org/micromamba-releases/releases/latest/download/micromamba-${plat}"
    if command -v curl >/dev/null 2>&1; then curl -Ls -o "$MM" "$url"
    elif command -v wget >/dev/null 2>&1; then wget -qO "$MM" "$url"
    else echo "error: need curl or wget to download micromamba" >&2; exit 1; fi
    chmod +x "$MM"
  fi
fi

echo ">> Using: $("$MM" --version 2>/dev/null || echo micromamba)  (root prefix: ${MAMBA_ROOT_PREFIX})"
echo ">> Creating env '${env_name}' from ${yml}"
"$MM" create --yes --name "$env_name" --file "$yml"

if [[ -n "$verify_key" ]]; then
  echo ">> Verifying imports (--env ${verify_key})"
  "$MM" run --name "$env_name" python "${VER_ROOT}/scripts/verify-env.py" --env "$verify_key"
fi

echo ">> Done. Run tools with:  ${MM} run --name ${env_name} <command>"
echo "   (env lives under ${MAMBA_ROOT_PREFIX}/envs/${env_name}; delete that tree to remove it)"
