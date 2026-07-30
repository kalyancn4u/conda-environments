#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# audit-env.sh — security & hygiene audit of an environment or a requirements set.
#
# Two independent checks, both CI-friendly (non-zero exit on findings):
#   1. VULNERABILITIES — runs `pip-audit` against the resolved package set to
#      report known CVEs (PyPI Advisory DB / OSV).
#   2. HYGIENE — for a conda env, detects conda/pip package CLASHES (the same
#      ABI-risk check the test-environments workflow enforces).
#
# Targets (pick one):
#   ./audit-env.sh --name py312-web           # an installed conda environment
#   ./audit-env.sh --venv .venv               # a venv directory
#   ./audit-env.sh --requirements path.txt    # a static requirements.txt (no install needed)
#   ./audit-env.sh 04-web                     # shorthand -> lockfiles/requirements/04-web.txt
#
# Options:
#   --no-vulns     skip the pip-audit step (hygiene only)
#   --json         ask pip-audit for JSON output (machine-readable)
#
# `pip-audit` is run WITHOUT installing it into your target: the script uses the
# first available runner — `uvx`, then `pipx run`, then a local `pip-audit`.
#
# NOTE ON CONDA: pip-audit reads PyPI (dist-info) metadata. Packages installed by
# conda still expose that metadata, so most are covered; a few conda-only native
# packages may not appear. The clash check complements this for conda envs.
# -----------------------------------------------------------------------------
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VER_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REQ_DIR="${VER_ROOT}/lockfiles/requirements"

usage() {
  cat >&2 <<EOF
Usage:
  $0 --name <conda-env>            audit an installed conda environment
  $0 --venv <dir>                  audit a venv directory
  $0 --requirements <file.txt>     audit a static requirements file
  $0 <name>                        shorthand -> ${REQ_DIR}/<name>.txt
Options: --no-vulns  --json
EOF
  exit 2
}

target_kind=""; target=""; do_vulns=1; json=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)         target_kind="conda"; target="${2:?}"; shift 2 ;;
    --venv)         target_kind="venv";  target="${2:?}"; shift 2 ;;
    --requirements) target_kind="req";   target="${2:?}"; shift 2 ;;
    --no-vulns)     do_vulns=0; shift ;;
    --json)         json=1; shift ;;
    -h|--help)      usage ;;
    -*)             echo "unknown option: $1" >&2; usage ;;
    *)
      # bare arg -> a requirements shorthand or literal path
      if [[ -f "$1" ]]; then target_kind="req"; target="$1"
      elif [[ -f "${REQ_DIR}/$1.txt" ]]; then target_kind="req"; target="${REQ_DIR}/$1.txt"
      else echo "error: could not resolve target '$1'" >&2; usage; fi
      shift ;;
  esac
done
[[ -z "$target_kind" ]] && usage

have() { command -v "$1" >/dev/null 2>&1; }
rc=0

# Build the audit argument list. For req files we audit statically (-r); for a
# live env/venv we freeze its packages to a temp file and audit that, so no tool
# needs to be installed into the target.
tmp=""; audit_src=""
cleanup() { [[ -n "$tmp" ]] && rm -f "$tmp"; }
trap cleanup EXIT

case "$target_kind" in
  req)
    [[ -f "$target" ]] || { echo "error: requirements file not found: $target" >&2; exit 1; }
    audit_src="$target"
    echo ">> Target: requirements file  ${target}"
    ;;
  conda)
    have conda || { echo "error: conda not found" >&2; exit 1; }
    tmp="$(mktemp)"; audit_src="$tmp"
    echo ">> Target: conda env  ${target}  (freezing installed packages)"
    conda run --no-capture-output -n "$target" python -m pip freeze 2>/dev/null \
      | grep -v ' @ ' > "$tmp" || true
    ;;
  venv)
    vpy="${target}/bin/python"; [[ -x "$vpy" ]] || vpy="${target}/Scripts/python.exe"
    [[ -x "$vpy" ]] || { echo "error: no interpreter under ${target}" >&2; exit 1; }
    tmp="$(mktemp)"; audit_src="$tmp"
    echo ">> Target: venv  ${target}  (freezing installed packages)"
    "$vpy" -m pip freeze 2>/dev/null | grep -v ' @ ' > "$tmp" || true
    ;;
esac

# --- 1) Vulnerability scan (pip-audit) -------------------------------------
if [[ $do_vulns -eq 1 ]]; then
  echo
  echo "== Vulnerability scan (pip-audit) =========================="
  pa_args=(-r "$audit_src" --progress-spinner off)
  [[ $json -eq 1 ]] && pa_args+=(-f json)

  if have uvx; then
    uvx pip-audit "${pa_args[@]}" || rc=1
  elif have uv; then
    uv tool run pip-audit "${pa_args[@]}" || rc=1
  elif have pipx; then
    pipx run pip-audit "${pa_args[@]}" || rc=1
  elif have pip-audit; then
    pip-audit "${pa_args[@]}" || rc=1
  else
    echo "!! pip-audit not runnable: install uv (recommended) or pipx." >&2
    echo "   e.g.  uvx pip-audit -r ${audit_src}" >&2
    rc=1
  fi
else
  echo ">> Skipping vulnerability scan (--no-vulns)."
fi

# --- 2) Hygiene: conda/pip clash (conda targets only) ----------------------
if [[ "$target_kind" == "conda" ]]; then
  echo
  echo "== Hygiene: conda/pip package clashes ======================"
  clash_rc=0
  ENV_NAME="$target" python - <<'PY' || clash_rc=$?
import json, os, subprocess, sys
name = os.environ["ENV_NAME"]
data = json.loads(subprocess.check_output(["conda", "list", "-n", name, "--json"]))
pip_pkgs   = {p["name"].lower() for p in data if p.get("channel") == "pypi"}
conda_pkgs = {p["name"].lower() for p in data if p.get("channel") != "pypi"}
clash = sorted(pip_pkgs & conda_pkgs)
if clash:
    print("conda/pip clash detected (same package from both sources):", clash)
    sys.exit(1)
print("no conda/pip clashes")
PY
  [[ $clash_rc -ne 0 ]] && rc=1
fi

echo
echo "==========================================================="
if [[ $rc -eq 0 ]]; then
  echo "PASS: no vulnerabilities or clashes detected."
else
  echo "FINDINGS: review the report above."
fi
exit $rc
