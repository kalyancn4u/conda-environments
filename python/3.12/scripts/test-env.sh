#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# test-env.sh — build and verify environment(s) in the SAME Miniforge container
#               that CI uses, so you can reproduce `test-environments` locally.
#
# Requires Docker. Mirrors .github/workflows/test-environments.yml (linux-64).
#
# Usage:
#   ./test-env.sh 01-core        # build + verify one environment
#   ./test-env.sh --all          # every testable environment, in order
#
# A named Docker volume caches downloaded packages between runs, so repeated
# invocations are much faster.
# -----------------------------------------------------------------------------
set -euo pipefail

IMAGE="condaforge/miniforge3:latest"
CACHE_VOL="conda_envs_pkgcache"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# env-file stem -> verify-env.py key (env name is always py312-<key>)
ORDER=(01-core 02-ml 03-deep-learning 04-web 05-tools 06-tensorflow 07-geospatial 08-timeseries)
declare -A KEY=(
  [01-core]=core [02-ml]=ml [03-deep-learning]=dl [04-web]=web
  [05-tools]=tools [06-tensorflow]=tf [07-geospatial]=geo [08-timeseries]=ts
)

if ! command -v docker >/dev/null 2>&1; then
  echo "error: docker is not installed / not on PATH" >&2; exit 1
fi

if [[ "${1:-}" == "--all" ]]; then
  targets=("${ORDER[@]}")
elif [[ $# -ge 1 ]]; then
  targets=("$1")
else
  echo "Usage: $0 <env-stem|--all>   e.g. $0 01-core" >&2; exit 2
fi

fail=0
for e in "${targets[@]}"; do
  key="${KEY[$e]:-}"
  if [[ -z "$key" ]]; then echo "error: unknown environment '$e'" >&2; exit 1; fi
  name="py312-$key"
  echo "==================== $e  ($name) ===================="
  # Run the exact CI steps inside the container: create + verify.
  if docker run --rm \
      -v "$REPO_ROOT":/repo -w /repo \
      -v "$CACHE_VOL":/opt/conda/pkgs \
      "$IMAGE" bash -lc "
        set -e
        mamba env create --yes --file python/3.12/environments/$e.yml
        conda run --no-capture-output -n $name \
          python python/3.12/scripts/verify-env.py --env $key
      "; then
    echo ">> PASS: $e"
  else
    echo ">> FAIL: $e"; fail=1
  fi
done

[[ $fail -eq 0 ]] && echo "All requested environments passed." || echo "One or more environments failed."
exit $fail
