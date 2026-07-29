# conda-environments

> Modular, reproducible, **conda-forge-first** Conda environments for Python 3.12 —
> a reference implementation for long-term, maintainable environment management.

[![validate](https://github.com/kalyancn4u/conda-environments/actions/workflows/validate.yml/badge.svg)](https://github.com/kalyancn4u/conda-environments/actions/workflows/validate.yml)
[![test-environments](https://github.com/kalyancn4u/conda-environments/actions/workflows/test-environments.yml/badge.svg)](https://github.com/kalyancn4u/conda-environments/actions/workflows/test-environments.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## Why this repository exists

Most Python environments rot the same way: a single `base` environment accumulates
years of direct dependencies, transitive dependencies, one-off experiments, and
deprecated libraries until it can no longer be solved or reproduced. This repository
is the antidote — a set of **small, single-purpose environments** that are:

- **Modular** — one environment per concern (core, ML, deep learning, web, tooling).
- **Reproducible** — human-readable `*.yml` for intent, machine-generated lockfiles for exact rebuilds.
- **conda-forge-first** — a single, consistent, community-maintained channel.
- **CPU-by-default** — portable everywhere; GPU/CUDA is documented, never hard-coded.
- **Minimally pinned** — pin only what is technically justified, so upgrades stay cheap.

## Repository layout

```text
conda-environments/
├── docs/                     # Architecture & operational documentation
├── python/
│   └── 3.12/                 # Everything targeting Python 3.12
│       ├── environments/     # The modular environment definitions
│       ├── templates/        # Ready-to-fork starting points
│       ├── scripts/          # Cross-platform create/update/verify helpers
│       └── lockfiles/        # Generated per-platform lockfiles (CI-maintained)
└── .github/workflows/        # Validation, environment tests, lockfile refresh
```

The `python/3.12/` prefix is intentional: adding `python/3.13/` later requires **no
restructuring** — see [docs/architecture.md](docs/architecture.md).

## The environments

| File | Env name | Purpose |
|------|----------|---------|
| [`01-core.yml`](python/3.12/environments/01-core.yml) | `py312-core` | The daily driver — scientific Python for ~80–90% of work |
| [`02-ml.yml`](python/3.12/environments/02-ml.yml) | `py312-ml` | Classical ML: gradient boosting, tuning, experiment tracking |
| [`03-deep-learning.yml`](python/3.12/environments/03-deep-learning.yml) | `py312-dl` | PyTorch + Lightning + Hugging Face (CPU) |
| [`04-web.yml`](python/3.12/environments/04-web.yml) | `py312-web` | FastAPI/Flask/Django + data apps + async servers |
| [`05-tools.yml`](python/3.12/environments/05-tools.yml) | `py312-tools` | Dev tooling: test, lint, type-check, browser automation |
| [`06-tensorflow.yml`](python/3.12/environments/06-tensorflow.yml) | `py312-tf` | TensorFlow + Keras 3 (isolated from PyTorch) |
| [`07-geospatial.yml`](python/3.12/environments/07-geospatial.yml) | `py312-geo` | Vector + raster geospatial (GeoPandas, GDAL, rasterio) |
| [`08-timeseries.yml`](python/3.12/environments/08-timeseries.yml) | `py312-ts` | Forecasting & change-point (Prophet, sktime, statsforecast) |
| [`98-legacy.yml`](python/3.12/environments/98-legacy.yml) | `py312-legacy` | Documented legacy/deprecated packages — reference only |

Templates for common personas live in [`python/3.12/templates/`](python/3.12/templates/):
`minimal`, `data-science`, `mlops`, `llm`.

> 🔰 **Brand new to conda?** Start with the
> [**complete beginner's guide**](python/3.12/GUIDE.md) — it explains every file in the
> `python/3.12/` tree and every artifact it generates, in plain English.

## Quick start

```bash
# 1. Ensure conda-forge is your default channel (see docs/compatibility.md)
conda config --add channels conda-forge
conda config --set channel_priority strict

# 2. Create the daily-driver environment
conda env create -f python/3.12/environments/01-core.yml

# 3. Activate it
conda activate py312-core

# 4. Sanity-check the install
python python/3.12/scripts/verify-env.py --env core
```

Prefer the helper scripts, which apply strict channel settings and friendly errors:

```bash
# Linux / macOS
./python/3.12/scripts/create-env.sh 01-core

# Windows PowerShell
.\python\3.12\scripts\create-env.ps1 01-core
```

> **Recommendation:** use [`mamba`](https://mamba.readthedocs.io/) (or `conda` ≥ 23.10
> with the libmamba solver) — the environments below solve in seconds instead of minutes.

## Building one "all-in-one" environment (iterative layering)

The environments are designed to be **used separately**. But you *can* merge them into a
single environment by **layering** the YAML files onto one target env, one after another,
with `conda env update`. This section documents exactly how — and the trade-offs, because
an all-in-one env re-introduces the very problems this repo was built to avoid.

### How the layering works

`conda env update -n <target> -f <file>` installs the packages from `<file>` **into an
existing environment**, solving them against whatever is already there. Passing `-n`
overrides the `name:` inside each YAML, so every file can target the *same* environment.
Run it once per file, in order, starting from `01-core`:

```bash
# Linux / macOS ── build "py312-all" by layering each environment file in sequence
cd python/3.12

# 1) Create the base from core (‑n names the merged env)
conda env create -n py312-all -f environments/01-core.yml

# 2) Layer the rest on top, one after another (order: light → heavy)
conda env update -n py312-all -f environments/02-ml.yml
conda env update -n py312-all -f environments/03-deep-learning.yml
conda env update -n py312-all -f environments/04-web.yml
conda env update -n py312-all -f environments/05-tools.yml

# 3) Verify everything still imports
conda activate py312-all
python scripts/verify-env.py --all
```

```powershell
# Windows PowerShell ── same sequence
Set-Location python\3.12
conda env create -n py312-all -f environments\01-core.yml
foreach ($f in '02-ml','03-deep-learning','04-web','05-tools') {
    conda env update -n py312-all -f "environments\$f.yml"
}
conda activate py312-all
python scripts\verify-env.py --all
```

Or as a loop on Linux/macOS:

```bash
conda env create -n py312-all -f environments/01-core.yml
for f in 02-ml 03-deep-learning 04-web 05-tools; do
  conda env update -n py312-all -f "environments/$f.yml" || {
    echo "!! layering failed at $f — resolve the conflict before continuing"; break; }
done
```

### ⚠️ Rules that make or break this approach

| Rule | Why it matters |
|------|----------------|
| **Never pass `--prune`** when layering | `--prune` removes anything not in the *current* file — it would delete every package from the previous layers. (This is why the `update-env.sh` helper, which *does* prune, is **not** used here.) |
| **Skip `98-legacy.yml`** | It is documentation, not a usable environment. |
| **Treat `06-tensorflow.yml` as high-risk** | TensorFlow and the PyTorch stack (`03`) pin conflicting low-level libs (`protobuf`, `abseil`, `numpy`). Adding both to one env frequently makes it **unsolvable** or silently downgrades packages. Prefer leaving TF out of the all-in-one; keep it in its own `py312-tf`. |
| **Go light → heavy** | Starting from `01-core` and adding heavier stacks last gives the solver the best chance and the clearest error if a conflict appears. |
| **Lock it once it works** | Because the merged env is fragile, capture it immediately: `scripts/export-env.sh py312-all` (snapshot) or generate a `conda-lock` lockfile, so you can rebuild the exact working set. |

### Pros and cons of an all-in-one environment

**Pros**
- **Convenience** — one env to activate; no switching between `py312-core`, `py312-ml`, etc.
- **One Jupyter kernel** that can do data work, ML, web, and DL in the same notebook.
- **Good for open-ended exploration** when you don't yet know which tools you'll reach for.
- **Simpler mental model** for beginners who find multiple environments confusing.

**Cons** (why we recommend *against* it for anything long-lived)
- **Fragility / conflicts** — the more you pile in, the higher the chance of an
  **unsatisfiable** solve. TF + PyTorch is the classic breaker.
- **Slow solves & updates** — every future change must re-solve a huge dependency graph;
  installs can take many minutes.
- **All-or-nothing failures** — one incompatible package can block upgrading *anything*.
- **Large footprint** — several GB of packages, most unused in any given task.
- **Harder to reproduce** — big merged envs are more likely to resolve differently over
  time; locking is essential but heavier.
- **It recreates the original problem** — this repository was distilled from exactly such
  a monolithic `base` environment. An all-in-one env drifts back toward that mess.

> **Recommendation:** use the modular environments for day-to-day and reproducible work.
> Reach for an all-in-one only as a short-lived convenience (a scratch/exploration env),
> keep TensorFlow out of it, and lock it the moment it works. See
> [docs/architecture.md](docs/architecture.md) for the reasoning behind the split.

## GPU / CUDA

Every environment ships **CPU builds** so they solve identically on Linux, Windows,
and Apple Silicon. GPU acceleration is deliberately **not** baked into the YAMLs.
See the CUDA strategy in [docs/compatibility.md](docs/compatibility.md#cuda-installation-strategy).

## Documentation

- [Beginner's guide](python/3.12/GUIDE.md) — every file & artifact explained for newcomers
- [Architecture](docs/architecture.md) — design & directory rationale
- [Package selection](docs/package-selection.md) — the philosophy behind every include/exclude
- [Compatibility](docs/compatibility.md) — channels, platforms, CUDA
- [Upgrade strategy](docs/upgrade-strategy.md) — how to move versions forward safely
- [Troubleshooting](docs/troubleshooting.md) — when solves fail
- [FAQ](docs/faq.md)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). In short: keep environments small, prefer
conda-forge, avoid unnecessary pins, and document non-obvious choices.

## License

[MIT](LICENSE).
