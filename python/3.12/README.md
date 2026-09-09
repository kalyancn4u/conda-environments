# Python 3.12 Environments

<sub>📍 [conda-environments](../../README.md) › **Python 3.12**</sub>

Everything version-specific for **Python 3.12** lives here. See the repository
[root README](../../README.md) for the big picture and the [docs/](../../docs/) tree
for architecture and rationale.

> 🔰 **New to conda?** Read [**GUIDE.md**](GUIDE.md) first — a complete, plain-English
> walkthrough of *every* file in this folder, what it does, when to use it, and what
> each command produces. No prior knowledge assumed.

## Contents

| Directory | What's inside |
|-----------|---------------|
| [`environments/`](environments/) | The modular environment definitions (`01`–`08` + `98-legacy`) + the upgrade report |
| [`templates/`](templates/) | Persona starting points: `minimal`, `data-science`, `mlops`, `llm`, `all-in-one-pytorch`, `all-in-one-tflow` |
| [`examples/`](examples/) | uv-to-conda sample inputs + the `environment.yml` they generate (`examples/uv-to-conda/`) |
| [`lockfiles/`](lockfiles/) | Exact-rebuild conda lockfiles per platform **and** uv `requirements.txt` for production |

> The helper scripts (create / update / verify / doctor / setup-venv / audit-env /
> micromamba-env / register-kernel) are **shared across versions** in the top-level
> [`scripts/`](../../scripts/) folder — pass `-p 3.12` to target this tree. See
> [docs/user-workflows.md](../../docs/user-workflows.md).

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

The helper scripts live in the shared [`scripts/`](../../scripts/) folder at the
repository root — run these **from the repo root** and pass **`-p 3.12`** to target this
tree.

```bash
# Create (Linux/macOS)
./scripts/create-env.sh -p 3.12 01-core

# Create (Windows PowerShell)
.\scripts\create-env.ps1 -p 3.12 01-core

# Update to match the YAML (prunes removed packages)
./scripts/update-env.sh -p 3.12 01-core

# Verify the key packages import
python scripts/verify-env.py -p 3.12 --env core

# Compare two environments / list upgradable packages
./scripts/compare-envs.sh py312-core py312-ds
./scripts/compare-envs.sh --outdated py312-core

# Reproduce CI locally: build + verify an env in the Miniforge container (needs Docker)
./scripts/test-env.sh -p 3.12 01-core        # one env      (Windows: .\scripts\test-env.ps1 -p 3.12 01-core)
./scripts/test-env.sh -p 3.12 --all          # every env
```

Wider workflows — the venv/uv, micromamba, security, and Jupyter helpers:

```bash
./scripts/doctor.sh -p 3.12                   # what's installed & configured? (read-only preflight)
./scripts/setup-venv.sh -p 3.12 04-web        # venv + pinned requirements (PyPI/production)
./scripts/micromamba-env.sh -p 3.12 01-core   # zero-install create + verify
./scripts/audit-env.sh -p 3.12 --name py312-web   # security: CVE scan + conda/pip clash check
./scripts/register-kernel.sh py312-ml     # expose an env as a Jupyter kernel
```

> Full, novice-friendly walkthroughs of every scenario (dev, notebooks, production,
> containers, testing/QA, security, CI/CD, MLOps) live in
> [docs/user-workflows.md](../../docs/user-workflows.md).

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
