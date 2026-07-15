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
