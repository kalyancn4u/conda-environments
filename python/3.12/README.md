# Python 3.12 Environments

Everything version-specific for **Python 3.12** lives here. See the repository
[root README](../../README.md) for the big picture and the [docs/](../../docs/) tree
for architecture and rationale.

> 🔰 **New to conda?** Read [**GUIDE.md**](GUIDE.md) first — a complete, plain-English
> walkthrough of *every* file in this folder, what it does, when to use it, and what
> each command produces. No prior knowledge assumed.

## Contents

| Directory | What's inside |
|-----------|---------------|
| [`environments/`](environments/) | The seven modular environment definitions + the upgrade report |
| [`templates/`](templates/) | Persona starting points: `minimal`, `data-science`, `mlops`, `llm`, `all-in-one-pytorch`, `all-in-one-tflow` |
| [`scripts/`](scripts/) | Create / update / export / clean / compare / verify helpers |
| [`lockfiles/`](lockfiles/) | Generated per-platform exact-rebuild lockfiles (CI-maintained) |

## Environments at a glance

| File | Env name | Create it when you need… |
|------|----------|--------------------------|
| `environments/01-core.yml` | `py312-core` | Everyday data analysis & notebooks |
| `environments/02-ml.yml` | `py312-ml` | Gradient boosting, tuning, tracking |
| `environments/03-deep-learning.yml` | `py312-dl` | PyTorch + Hugging Face (CPU) |
| `environments/04-web.yml` | `py312-web` | Web APIs / data apps |
| `environments/05-tools.yml` | `py312-tools` | Testing, linting, automation |
| `environments/06-tensorflow.yml` | `py312-tf` | TensorFlow + Keras (isolated) |
| `environments/07-geospatial.yml` | `py312-geo` | Geospatial vector/raster analysis |
| `environments/08-timeseries.yml` | `py312-ts` | Forecasting & change-point detection |
| `environments/98-legacy.yml` | `py312-legacy` | Reference only (deprecated packages) |

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
./scripts/compare-envs.sh py312-core py312-ds
./scripts/compare-envs.sh --outdated py312-core

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
