#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# compare-envs.sh — diff the installed packages of two environments,
#                   or list outdated packages in one environment.
#
# Usage:
#   ./compare-envs.sh py312-core py312-ds     # diff two environments
#   ./compare-envs.sh --outdated py312-core   # list packages with newer versions
#
# Output uses standard `diff` markers:
#   <  only in / different version in the FIRST env
#   >  only in / different version in the SECOND env
# -----------------------------------------------------------------------------
set -euo pipefail

# --- Outdated mode --------------------------------------------------------
if [[ "${1:-}" == "--outdated" ]]; then
  env_name="${2:?usage: $0 --outdated <env-name>}"
  echo ">> Checking for outdated packages in '${env_name}' (dry run)..."
  # A dry-run full update reveals which packages *could* move forward.
  conda update --all --name "$env_name" --dry-run
  exit 0
fi

# --- Diff mode ------------------------------------------------------------
if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <env-a> <env-b>            (diff two envs)" >&2
  echo "       $0 --outdated <env-name>      (list upgradable packages)" >&2
  exit 2
fi

a="$1"; b="$2"
tmp_a="$(mktemp)"; tmp_b="$(mktemp)"
trap 'rm -f "$tmp_a" "$tmp_b"' EXIT

# Normalize to "name version" columns, sorted, for a clean diff.
conda list --name "$a" | grep -v '^#' | awk '{print $1, $2}' | sort > "$tmp_a"
conda list --name "$b" | grep -v '^#' | awk '{print $1, $2}' | sort > "$tmp_b"

echo ">> Comparing '${a}' (<) against '${b}' (>):"
if diff "$tmp_a" "$tmp_b"; then
  echo ">> Environments are identical."
fi
