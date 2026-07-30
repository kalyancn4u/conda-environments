# Python 3.10 Environments

<sub>📍 [conda-environments](../../README.md) › **Python 3.10**</sub>

Everything version-specific for **Python 3.10** lives here. See the repository
[root README](../../README.md) for the big picture and the [docs/](../../docs/) tree
for architecture and rationale.

> 🔰 **New to conda?** Read [**GUIDE.md**](GUIDE.md) first — a complete, plain-English
> walkthrough of *every* file in this folder, what it does, when to use it, and what
> each command produces. No prior knowledge assumed.

## ✅ Python 3.10 readiness

Python 3.10 is mature, so conda-forge has broad 3.10 coverage. **Verified by dry-run solves
against conda-forge (2026-07-30): all 8 environments and all 6 templates solve cleanly** —
kept at parity with [`python/3.12`](../3.12/). Re-check any time with:

```bash
conda env create --dry-run -f environments/01-core.yml
```

**Legacy packages on 3.10.** Because 3.10 predates some newer stdlib features, a couple of
packages we treat as *legacy* for 3.12 are genuinely useful **if your own code needs them**
on 3.10 — most notably `backports.strenum` (`enum.StrEnum` is 3.11+). They're documented
(commented) in [`environments/98-legacy.yml`](environments/98-legacy.yml); the curated
environments here don't require any of them, so nothing was added.

**Lockfiles are generated and committed** — conda `linux-64` explicit locks for all 14
environments/templates in [`lockfiles/linux-64/`](lockfiles/linux-64/), plus uv-pinned
[`requirements/*.txt`](lockfiles/requirements/) (Python 3.10 / linux). Rebuild with
`conda create --file …` (or `conda-lock install` for locks carrying `# pip` lines) or
`uv pip install -r …`. `win-64`/`osx-arm64` conda locks are still generated on demand.

## Contents

| Directory | What's inside |
|-----------|---------------|
| [`environments/`](environments/) | The modular environment definitions (`01`–`08` + `98-legacy`) + the upgrade report |
| [`templates/`](templates/) | Persona starting points: `minimal`, `data-science`, `mlops`, `llm`, `all-in-one-pytorch`, `all-in-one-tflow` |
| [`scripts/`](scripts/) | Create / update / export / clean / compare / verify / test helpers |
| [`lockfiles/`](lockfiles/) | Exact-rebuild conda lockfiles per platform **and** uv `requirements.txt` for production |

## Environments at a glance

| File | Env name | Create it when you need… |
|------|----------|--------------------------|
| `environments/01-core.yml` | `py310-core` | Everyday data analysis & notebooks |
| `environments/02-ml.yml` | `py310-ml` | Gradient boosting, tuning, tracking |
| `environments/03-deep-learning.yml` | `py310-dl` | PyTorch + Hugging Face (CPU) |
| `environments/04-web.yml` | `py310-web` | Web APIs / data apps |
| `environments/05-tools.yml` | `py310-tools` | Testing, linting, automation |
| `environments/06-tensorflow.yml` | `py310-tf` | TensorFlow + Keras (isolated) |
| `environments/07-geospatial.yml` | `py310-geo` | Geospatial vector/raster analysis |
| `environments/08-timeseries.yml` | `py310-ts` | Forecasting & change-point detection |
| `environments/98-legacy.yml` | `py310-legacy` | Reference only (deprecated packages) |

## Common commands

```bash
# Create (Linux/macOS)
./scripts/create-env.sh 01-core

# Create (Windows PowerShell)
.\scripts\create-env.ps1 01-core

# Update to match the YAML (prunes removed packages)
./scripts/update-env.sh 01-core

# Verify the key packages import
python scripts/verify-env.py --env core

# Compare two environments / list upgradable packages
./scripts/compare-envs.sh py310-core py310-ds
./scripts/compare-envs.sh --outdated py310-core

# Reproduce CI locally: build + verify an env in the Miniforge container (needs Docker)
./scripts/test-env.sh 01-core        # one env      (Windows: .\scripts\test-env.ps1 01-core)
./scripts/test-env.sh --all          # every env
```

> CI (`test-environments`) builds every environment on the free **Linux** runner inside
> the `condaforge/miniforge3` container. `test-env.sh` runs that exact job on your
> machine. See [docs/compatibility.md](../../docs/compatibility.md) for why CI is
> Linux-only.

## Before you start

Set conda-forge as the default channel with strict priority (once per machine):

```bash
conda config --add channels conda-forge
conda config --set channel_priority strict
```

Platform caveats (full matrix in [docs/compatibility.md](../../docs/compatibility.md)):

- **TensorFlow** has no conda-forge **win-64** build — install via pip on Windows.
- **gunicorn** (in `04-web`) is POSIX-only — use `uvicorn`/`waitress` on Windows.
- All environments are **CPU-only**; see the CUDA section for GPU.
