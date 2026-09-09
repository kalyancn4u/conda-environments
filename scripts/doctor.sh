#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# doctor.sh — inspect the local toolchain and report readiness.
#
# A read-only preflight: it installs nothing and changes nothing. It answers
# "which environment tools do I have, are they configured correctly, and is my
# shell in a safe state to install packages?" — the first thing to run on a new
# machine or in a CI job before create/setup steps.
#
# Usage:
#   ./doctor.sh                 # human-readable report (always exits 0)
#   ./doctor.sh -p 3.12         # tailor the context banner / hints to a tree
#   ./doctor.sh --strict        # exit non-zero if no conda-family solver AND no uv
#
# This is a pure toolchain preflight, so -p/--python is OPTIONAL here: pass it to
# label the report with a Python-version context and version-specific next steps;
# omit it and the report is version-neutral.
# -----------------------------------------------------------------------------
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- optional -p/--python and --strict --------------------------------------
PYVER=""; strict=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--python) PYVER="${2:-}"; shift 2 ;;
    -p=*|--python=*) PYVER="${1#*=}"; shift ;;
    --strict) strict=1; shift ;;
    *) shift ;;
  esac
done
PYTAG="${PYVER:+py${PYVER//./}}"               # py312 when -p given, else empty
HINT_VER="${PYVER:-3.12}"                       # placeholder for example commands

# --- tiny reporting helpers -------------------------------------------------
ok()   { printf '  \033[32mOK\033[0m   %s\n' "$*"; }
warn() { printf '  \033[33m!!\033[0m   %s\n' "$*"; }
miss() { printf '  \033[31m--\033[0m   %s\n' "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }

# First line of `<tool> --version`, trimmed — resilient to tools that print
# multi-line banners or write the version to stderr.
ver() { "$@" 2>&1 | head -n1 | tr -d '\r'; }

if [[ -n "$PYVER" ]]; then
  echo "conda-environments doctor — context: python/${PYVER} (${PYTAG}-*)"
else
  echo "conda-environments doctor — version-neutral (pass -p X.Y for a tree context)"
fi
echo "==========================================================="

# --- 1) Solvers / installers -----------------------------------------------
echo
echo "Solvers & installers"
have conda      && ok   "conda        $(ver conda --version)"          || miss "conda        (not found)"
have mamba      && ok   "mamba        $(ver mamba --version | head -n1)" || warn "mamba        (not found — optional, but far faster than conda)"
have micromamba && ok   "micromamba   $(ver micromamba --version)"     || warn "micromamba   (not found — needed only for the zero-install path)"
have uv         && ok   "uv           $(ver uv --version)"             || warn "uv           (not found — needed for the venv/production path)"
have pip        && ok   "pip          $(ver pip --version)"            || warn "pip          (not found on this interpreter)"
have conda-lock && ok   "conda-lock   $(ver conda-lock --version)"     || warn "conda-lock   (not found — needed only to generate lockfiles locally)"

# --- 2) Interpreters & container tooling -----------------------------------
echo
echo "Interpreters & tooling"
have python  && ok "python   $(ver python --version)"  || { have python3 && ok "python3  $(ver python3 --version)" || miss "python   (not found)"; }
have docker  && ok "docker   $(ver docker --version)"  || warn "docker   (not found — needed only for containerized builds/tests)"
have git     && ok "git      $(ver git --version)"     || warn "git      (not found)"

# --- 3) conda channel configuration ----------------------------------------
echo
echo "conda channel configuration"
if have conda; then
  channels="$(conda config --show channels 2>/dev/null || true)"
  priority="$(conda config --show channel_priority 2>/dev/null || true)"
  if echo "$channels" | grep -q 'conda-forge'; then
    ok "conda-forge is in your channel list"
  else
    warn "conda-forge not found in channels — run: conda config --add channels conda-forge"
  fi
  if echo "$priority" | grep -qi 'strict'; then
    ok "channel_priority is strict"
  else
    warn "channel_priority is not strict — run: conda config --set channel_priority strict"
  fi
else
  warn "conda not installed — skipping channel checks"
fi

# --- 4) Shell state: is it safe to run uv/pip right now? --------------------
echo
echo "Current shell state (matters before running uv/pip)"
conda_active="${CONDA_PREFIX:-}"
venv_active="${VIRTUAL_ENV:-}"
if [[ -n "$conda_active" && -n "$venv_active" ]]; then
  warn "BOTH a conda env ($(basename "$conda_active")) and a venv are active — deactivate one"
elif [[ -n "$conda_active" ]]; then
  # base is usually harmless; a named env is the risky target for uv/pip.
  if [[ "${CONDA_DEFAULT_ENV:-}" == "base" ]]; then
    ok "conda 'base' is active (fine); activate a project env for conda work"
  else
    warn "conda env '${CONDA_DEFAULT_ENV:-?}' is ACTIVE — do NOT run uv/pip now (it would install into it)."
    warn "    For PyPI/venv work run 'conda deactivate' first. See docs/conda-vs-uv.md §5."
  fi
elif [[ -n "$venv_active" ]]; then
  ok "a venv is active ($venv_active) — safe target for uv/pip"
else
  ok "no conda env or venv active — clean shell"
fi

# --- 5) Verdict -------------------------------------------------------------
echo
echo "==========================================================="
solver_ok=0
{ have conda || have mamba || have micromamba; } && solver_ok=1
if [[ $solver_ok -eq 1 ]]; then
  echo "Ready for the conda/mamba path. Next: ./scripts/create-env.sh -p ${HINT_VER} 01-core"
else
  echo "No conda-family solver found. Install Miniforge (conda+mamba) for the dev path."
fi
if have uv || have pip; then
  echo "Ready for the venv/uv path.   Next: ./scripts/setup-venv.sh -p ${HINT_VER} 04-web"
fi

if [[ $strict -eq 1 && $solver_ok -eq 0 ]] && ! have uv; then
  echo "strict: no solver and no uv — failing." >&2
  exit 1
fi
exit 0
