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
│   ├── 3.10/                 # Python 3.10 (validated; linux-64 locks + uv requirements)
│   ├── 3.12/                 # Everything targeting Python 3.12 (primary, fully locked)
│   │   ├── environments/     # The modular environment definitions
│   │   ├── templates/        # Ready-to-fork starting points
│   │   ├── scripts/          # Cross-platform create/update/verify helpers
│   │   └── lockfiles/        # conda lockfiles + uv requirements
│   └── …                     # add python/3.13, 3.14, … by copying 3.12 and bumping pins
└── .github/workflows/        # Validation, environment tests, lockfile refresh
```

The `python/<version>/` prefix is intentional: [`python/3.10/`](python/3.10/) was added by
**copying `3.12` and bumping the pins — no restructuring** (see
[docs/architecture.md](docs/architecture.md)). All 8 environments + 6 templates solve on
conda-forge, and it now ships **`linux-64` conda lockfiles + uv `requirements.txt`** (at
parity with 3.12); 3.12 remains the primary reference.

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
`minimal`, `data-science`, `mlops`, `llm`, and two kitchen-sink variants —
`all-in-one-pytorch` and `all-in-one-tflow`.

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
single environment. The quickest way is a ready-made kitchen-sink template — pick the
deep-learning framework you want (they can't reliably coexist):

```bash
# PyTorch variant (env py312-all-pytorch)
conda env create -f python/3.12/templates/all-in-one-pytorch.yml
# …or the TensorFlow variant (env py312-all-tflow)
conda env create -f python/3.12/templates/all-in-one-tflow.yml
```

Alternatively you can **layer** the individual YAML files onto one target env, one after
another, with `conda env update` (shown below). Either way, read the trade-offs — an
all-in-one env re-introduces the very problems this repo was built to avoid.

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

## Lockfiles (exact, reproducible rebuilds)

The `*.yml` files capture **intent** (loosely pinned, so upgrades stay cheap). For
**byte-for-byte reproducibility**, generate per-platform [`conda-lock`](https://github.com/conda/conda-lock)
lockfiles under [`python/3.12/lockfiles/`](python/3.12/lockfiles/) — a frozen list of exact
package URLs + `sha256` hashes that rebuilds an environment identically.

The easiest way (no local install) is the **GitHub Actions** path — it runs on a Linux
runner and opens a PR with the results:

> Repo → **Actions → update-lockfiles → Run workflow** (defaults to `linux-64`).

Then rebuild from a lock with:

```bash
conda create --name py312-core --file python/3.12/lockfiles/linux-64/01-core.conda.lock
```

- 🎓 **Understand it:** [How lockfile generation works, from zero to mastery](python/3.12/lockfiles/LOCKFILES-EXPLAINED.md)
- 🛠️ **Run it:** [Lockfiles overview & generation methods — Actions, Docker, WSL](python/3.12/lockfiles/README.md)

### Production installs with uv

For **production / CI-CD**, this repo also ships fully-pinned, PyPI-only
[`requirements.txt`](python/3.12/lockfiles/requirements/) files (one per environment &
template), resolved with [uv](https://github.com/astral-sh/uv):

```bash
python -m venv .venv && source .venv/bin/activate   # or: uv venv   (isolated env)
uv pip install -r python/3.12/lockfiles/requirements/04-web.txt
```

**When to use which:** develop with **conda/mamba** (Python + native libraries like GDAL,
CUDA); ship with a **`venv` + uv** when the service's dependencies are pure-PyPI. Full
novice-friendly explanation — `venv` vs. conda environments, and why CD favors uv — in
[docs/conda-vs-uv.md](docs/conda-vs-uv.md).

## Documentation — a learning path (novice → mastery)

New here? Read these **in order** — each builds on the last, and they take you from "never
used conda" to "can maintain the whole system." No prior knowledge assumed. This map also
lives at [`docs/README.md`](docs/README.md).

**① Start — get productive**
1. [Beginner's guide](python/3.12/GUIDE.md) — what every file & generated artifact is, in plain English, with a first-session walkthrough.
2. [Environments & installers: conda / mamba / micromamba vs. venv + pip / uv](docs/conda-vs-uv.md) — the tools themselves: virtual environments from scratch, which to use when, dev-vs-production, why CD uses uv, and how to keep uv from clobbering a conda env.

**② Understand — the design**
3. [Architecture](docs/architecture.md) — why it's split this way; the environment matrix.
4. [Package selection](docs/package-selection.md) — the philosophy behind every include/exclude, and the conda↔PyPI name gotchas.
5. [Compatibility](docs/compatibility.md) — channels, per-platform support, and the CUDA/GPU strategy.

**③ Reproduce — lockfiles & production**
6. [Lockfiles — explained](python/3.12/lockfiles/LOCKFILES-EXPLAINED.md) — reproducibility from first principles.
7. [Lockfiles — overview & generation methods](python/3.12/lockfiles/README.md) — Actions / Docker / WSL commands, and how to *use* a lock.
8. [uv requirements](python/3.12/lockfiles/requirements/README.md) — pinned PyPI installs for production/CI-CD.

**④ Maintain — keep it healthy**
9. [Upgrade strategy](docs/upgrade-strategy.md) — moving versions forward safely.
10. [Troubleshooting](docs/troubleshooting.md) — when solves fail · [FAQ](docs/faq.md) — quick answers.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). In short: keep environments small, prefer
conda-forge, avoid unnecessary pins, and document non-obvious choices.

## License

[MIT](LICENSE).
