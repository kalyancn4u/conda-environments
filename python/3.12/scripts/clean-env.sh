#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# clean-env.sh — reclaim disk space from Conda caches
#
# Usage:
#   ./clean-env.sh              # dry-run: show what would be removed
#   ./clean-env.sh --yes        # actually clean (tarballs, index cache, unused pkgs)
#
# Safe: this only touches the package/index CACHE, never your environments.
# -----------------------------------------------------------------------------
set -euo pipefail

confirm="${1:-}"

if [[ "$confirm" != "--yes" ]]; then
  echo ">> DRY RUN. This would run: conda clean --all"
  echo ">> Re-run with '--yes' to actually clean the caches."
  conda clean --all --dry-run || true
  exit 0
fi

echo ">> Cleaning conda caches (tarballs, index cache, unused packages)..."
conda clean --all --yes
echo ">> Cache cleaned."
