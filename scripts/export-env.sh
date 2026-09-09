#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# export-env.sh — snapshot an ACTIVE/named environment for reproducibility
#
# Usage:
#   ./export-env.sh py312-core            # writes to ./exports/
#   ./export-env.sh py312-core /tmp/out   # custom output dir
#
# Produces three artifacts:
#   <env>-frozen.yml     : full solve with exact versions+builds (this platform)
#   <env>-nobuild.yml    : versions only, no build strings (more portable)
#   <env>-explicit.txt   : `conda list --explicit` URL list (exact rebuild)
#
# These are throwaway snapshots (gitignored). For cross-platform reproducibility,
# prefer conda-lock lockfiles (see update-lockfiles workflow).
# -----------------------------------------------------------------------------
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <env-name> [output-dir]" >&2
  exit 2
fi

env_name="$1"
out_dir="${2:-exports}"
mkdir -p "$out_dir"

echo ">> Exporting '${env_name}' to ${out_dir}/ ..."
conda env export      --name "$env_name"               > "${out_dir}/${env_name}-frozen.yml"
conda env export      --name "$env_name" --no-builds    > "${out_dir}/${env_name}-nobuild.yml"
conda list --explicit --name "$env_name"                > "${out_dir}/${env_name}-explicit.txt"

echo ">> Wrote:"
echo "   ${out_dir}/${env_name}-frozen.yml"
echo "   ${out_dir}/${env_name}-nobuild.yml"
echo "   ${out_dir}/${env_name}-explicit.txt"
