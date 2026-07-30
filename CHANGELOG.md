# Changelog

All notable changes to this repository are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- **conda `linux-64` lockfiles** for all 8 environments **and all 6 templates** under
  `lockfiles/linux-64/` (explicit `conda-lock` files) for exact reproducible rebuilds.
  `mlops` is included by pinning `sagemaker==2.75.1` — newer releases pull `torch →
  nvidia-cublas` CUDA wheels that conda-lock's pip solver can't resolve (and 2.75.1 is the
  newest version that co-resolves with airflow/boto3, matching uv). The `update-lockfiles`
  workflow now covers templates too, and skips TensorFlow templates on win-64.
- Verified the linux-64 locks install end-to-end (via micromamba/conda-lock) and
  documented the install-method nuance: **conda-only locks use `conda create --file`;
  locks carrying `# pip` lines (05-tools, llm, all-in-one-*) use `conda-lock install`** so
  the pip packages (e.g. playwright) are included.
- Documented that **uv `requirements.txt` are OS- and Python-version-specific** (compiled
  for linux + py3.12), with how to recompile for other targets or use `--universal`; and
  added a novice **mamba vs. micromamba** section and dev/prod **quick-reference** commands.
- **uv production requirements**: `python/3.12/lockfiles/requirements/` with a
  `requirements.in` (PyPI-name intent) and uv-compiled, fully-pinned `requirements.txt`
  for every environment and template (14 each), for production/CI-CD installs with uv.
- `docs/conda-vs-uv.md` — a beginner-friendly explainer of conda/mamba vs. **venv** + pip/uv:
  what a virtual environment is, the `venv` lifecycle, conda-env-vs-venv comparison, `uv venv`,
  the dev-vs-prod split, why CD favors uv, and the conda↔PyPI name gotchas. Linked from the
  README and the lockfiles/requirements docs.
- `07-geospatial.yml` (`py312-geo`) — GeoPandas/Shapely/PyProj/Fiona + GDAL/rasterio
  vector & raster stack, plus folium/contextily/mapclassify and geoalchemy2.
- `08-timeseries.yml` (`py312-ts`) — Prophet/cmdstanpy, sktime, statsforecast,
  statsmodels, and ruptures for forecasting & change-point detection.
- Both added to the verifier (`verify-env.py`), the `test-environments` CI matrix,
  and the `update-lockfiles` workflow; documented in the READMEs and GUIDE.
- Two kitchen-sink templates — `all-in-one-pytorch.yml` (`py312-all-pytorch`) and
  `all-in-one-tflow.yml` (`py312-all-tflow`) — unioning the modular stacks with one deep
  learning framework each (they can't coexist), with rationale in the file headers and
  prominent caveats. Added matching `allinone-pytorch` / `allinone-tflow` verifier sets
  and threaded both through the READMEs, GUIDE, FAQ, and architecture docs.
- Lockfile documentation consolidated into `python/3.12/lockfiles/`: `README.md` (overview
  + Actions/Docker/WSL command reference) and `LOCKFILES-EXPLAINED.md` (a from-first-
  principles teaching explainer); the `generation/` subfolder was removed. Root README
  gained a **Lockfiles** section. `update-lockfiles` now defaults manual runs to
  `linux-64` and is hardened against `conda-lock` filename edge cases.
- `python/3.12/GUIDE.md` — a complete, beginner-friendly walkthrough documenting every
  file in the 3.12 tree and every artifact it generates; linked from both READMEs.
- README section on building an "all-in-one" environment by iteratively layering the
  environment YAMLs with `conda env update`, including the `--prune`/TensorFlow caveats
  and an honest pros/cons analysis.

### Fixed
All three diagnosed by reproducing the linux-64 solves/imports locally with a throwaway
micromamba (no permanent install).
- CI `ml` (env-solve): `02-ml.yml` and both all-in-one templates used `feature-engine`,
  which does not exist on conda-forge — the package is `feature_engine` (underscore; the
  PyPI/pip name is `feature-engine`). Fixed; verified it resolves cleanly.
- CI `tools` (verify-imports): the conda-forge `playwright` package is the browser
  *driver*, not the importable Python API, so `import playwright` failed — moved
  `playwright` to a `pip:` install. Also dropped `ruff` from the `verify-env.py` checks
  (a CLI with no importable module).
- CI `dl` (verify-imports): removed `albumentations` — its conda-forge build is broken
  (`albucore` hard-imports `simsimd`, which conda-forge doesn't reliably provide); pip
  would clash with conda `opencv`. Documented the pip-in-venv alternative. (The test
  container also installs `libgl1`/`libglib2.0-0` for `opencv`.)

### Changed (continued)
- Moved `xlrd` from `01-core` to `98-legacy` (reads only the obsolete `.xls` format;
  use `openpyxl`/`pandas` for `.xlsx`). Documented the `feature_engine`↔`feature-engine`
  and other conda-forge/PyPI/import name quirks in `docs/package-selection.md`.

### Changed
- `02-ml.yml` — added clustering/manifold (`hdbscan`, `umap-learn`), extra estimators
  (`mlxtend`, `skops`), and interpretability (`eli5`), surfaced by auditing 60 legacy
  environment files against the repo.
- CI standardized on the `condaforge/miniforge3` container on the free Linux runner:
  `test-environments` now builds/verifies **Linux-only** (dropped the Windows/macOS
  matrix to save CI minutes), and `update-lockfiles` uses the same container.
- Added `scripts/test-env.sh` / `test-env.ps1` to reproduce the CI build+verify locally
  in that container; documented in the READMEs, GUIDE, and compatibility docs.
- `docs/architecture.md` — expanded the environment matrix into a full table covering
  every environment YAML (env name, concern, headline packages, CPU/GPU, platforms,
  rationale) plus a companion templates table.

## [1.0.0] - 2026-07-15

### Added
- Initial modular environment architecture for **Python 3.12** under `python/3.12/`.
- Seven environments: `01-core`, `02-ml`, `03-deep-learning`, `04-web`,
  `05-tools`, `06-tensorflow`, `98-legacy`.
- Four templates: `minimal`, `data-science`, `mlops`, `llm`.
- Cross-platform scripts (Bash + PowerShell) for create/update/export/clean/compare
  plus a Python import verifier (`verify-env.py`).
- Documentation set under `docs/` (architecture, package selection, compatibility,
  upgrade strategy, troubleshooting, FAQ).
- GitHub Actions: `validate`, `test-environments`, `update-lockfiles`.
- Upgrade report at `python/3.12/environments/99-upgrade-candidates.md`.

### Design decisions
- Standardized on a **single `conda-forge` channel** with `channel_priority: strict`.
- **CPU-only** environment definitions; GPU/CUDA documented separately.
- Split **TensorFlow** (`06-tensorflow`) from the **PyTorch** deep-learning stack
  (`03-deep-learning`) to avoid framework dependency contention.
- Moved orchestration (Apache Airflow) and cloud SDKs (SageMaker) out of the core
  modules into `templates/mlops.yml`.
- Adopted **minimal version pinning**: only `python` is pinned by default.

### Migrated from source `base` environment
- Removed stdlib backports not needed on 3.12 (`dataclasses`, `typing`, `backports.strenum`).
- Removed deprecated packages (`backcall`, `pickleshare`, `entrypoints`,
  `keras-preprocessing`, `tensorflow-estimator`, `tensorboard-plugin-wit`).
- Removed build toolchains erroneously present as dependencies (`m2w64-*`,
  `mingw-w64-*`, `msys2-*`).
- Flagged `transformers==2.1.1` (2019-era) as incompatible; replaced with a modern
  Hugging Face stack.

[Unreleased]: https://github.com/kalyancn4u/conda-environments/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/kalyancn4u/conda-environments/releases/tag/v1.0.0
