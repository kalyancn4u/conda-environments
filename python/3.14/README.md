# Python 3.14 Environments

<sub>📍 [conda-environments](../../README.md) › **Python 3.14**</sub>

Everything version-specific for **Python 3.14** lives here. See the repository
[root README](../../README.md) for the big picture and the [docs/](../../docs/) tree
for architecture and rationale.

> 🔰 **New to conda?** Read [**GUIDE.md**](GUIDE.md) first — a complete, plain-English
> walkthrough of *every* file in this folder, what it does, when to use it, and what
> each command produces. No prior knowledge assumed.

## ⚠️ Python 3.14 readiness

Python 3.14 (released Oct 2025) is **new**. This tree is at **structural parity with
[`python/3.12`](../3.12/)** (copy + version-pin bump to `python=3.14.*`, `py314-*`), but
conda-forge build coverage for 3.14 is still catching up — the **heaviest stacks may not
solve yet**, most notably **TensorFlow** ([`06-tensorflow.yml`](environments/06-tensorflow.yml)
and [`all-in-one-tflow`](templates/all-in-one-tflow.yml)) and possibly parts of the
deep-learning and geospatial trees.

> **Validation status — treat every environment as unverified on 3.14 until you solve it.**
> Nothing here was solved in the session that created the tree (no conda-forge network
> access). The lighter environments (`01-core`, `04-web`, `05-tools`, `08-timeseries`) are
> the most likely to work today; the framework-heavy ones (`03-deep-learning`,
> `06-tensorflow`, `07-geospatial`, both `all-in-one-*`) are the most likely to lag upstream.
> Check any one before relying on it:
>
> ```bash
> conda env create --dry-run -f environments/01-core.yml
> ```
>
> When a heavy stack won't solve, that's an **upstream conda-forge coverage gap for 3.14**,
> not a repo bug — use [`python/3.12`](../3.12/) (or [`3.13`](../3.13/)) for that workload
> until the builds land.

**Lockfiles are generated on demand.** Only the version-neutral `requirements/*.in` intent
files and the docs are committed; the `linux-64/` conda locks and uv `requirements/*.txt`
should be produced with the
[`update-lockfiles`](../../.github/workflows/update-lockfiles.yml) workflow **once the needed
3.14 builds are available** on conda-forge.

## Contents

| Directory | What's inside |
|-----------|---------------|
| [`environments/`](environments/) | The modular environment definitions (`01`–`08` + `98-legacy`) + the upgrade report |
| [`templates/`](templates/) | Persona starting points: `minimal`, `data-science`, `mlops`, `llm`, `all-in-one-pytorch`, `all-in-one-tflow` |
| [`examples/`](examples/) | uv-to-conda sample inputs + the `environment.yml` they generate (`examples/uv-to-conda/`) |
| [`lockfiles/`](lockfiles/) | Per-platform conda lockfiles + uv `requirements.txt` — **generated on demand** for this tree (so far only the `requirements/*.in` intent files + docs are committed; see the readiness note above) |

> The helper scripts (create / update / verify / doctor / setup-venv / audit-env /
> micromamba-env / register-kernel) are **shared across versions** in the top-level
> [`scripts/`](../../scripts/) folder — pass `-p 3.14` to target this tree. New to them?
> Read the [scripts guide](../../docs/scripts.md); for task recipes see the
> [cookbook](../../docs/user-workflows.md).

## Environments at a glance

| File | Env name | Create it when you need… |
|------|----------|--------------------------|
| `environments/01-core.yml` | `py314-core` | Everyday data analysis & notebooks |
| `environments/02-ml.yml` | `py314-ml` | Gradient boosting, tuning, tracking |
| `environments/03-deep-learning.yml` | `py314-dl` | PyTorch + Hugging Face (CPU) |
| `environments/04-web.yml` | `py314-web` | Web APIs / data apps |
| `environments/05-tools.yml` | `py314-tools` | Testing, linting, automation |
| `environments/06-tensorflow.yml` | `py314-tf` | TensorFlow + Keras (isolated) |
| `environments/07-geospatial.yml` | `py314-geo` | Geospatial vector/raster analysis |
| `environments/08-timeseries.yml` | `py314-ts` | Forecasting & change-point detection |
| `environments/98-legacy.yml` | `py314-legacy` | Reference only (deprecated packages) |

## Common commands

The helper scripts live in the shared [`scripts/`](../../scripts/) folder at the
repository root — run these **from the repo root** and pass **`-p 3.14`** to target this
tree.

```bash
# Create (Linux/macOS)
./scripts/create-env.sh -p 3.14 01-core

# Create (Windows PowerShell)
.\scripts\create-env.ps1 -p 3.14 01-core

# Update to match the YAML (prunes removed packages)
./scripts/update-env.sh -p 3.14 01-core

# Verify the key packages import
python scripts/verify-env.py -p 3.14 --env core

# Compare two environments / list upgradable packages
./scripts/compare-envs.sh py314-core py314-ds
./scripts/compare-envs.sh --outdated py314-core

# Reproduce CI locally: build + verify an env in the Miniforge container (needs Docker)
./scripts/test-env.sh -p 3.14 01-core        # one env      (Windows: .\scripts\test-env.ps1 -p 3.14 01-core)
./scripts/test-env.sh -p 3.14 --all          # every env
```

Wider workflows — the venv/uv, micromamba, security, and Jupyter helpers:

```bash
./scripts/doctor.sh -p 3.14                   # what's installed & configured? (read-only preflight)
./scripts/setup-venv.sh -p 3.14 04-web        # venv + pinned requirements (PyPI/production)
./scripts/micromamba-env.sh -p 3.14 01-core   # zero-install create + verify
./scripts/audit-env.sh -p 3.14 --name py314-web   # security: CVE scan + conda/pip clash check
./scripts/register-kernel.sh py314-ml     # expose an env as a Jupyter kernel
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
