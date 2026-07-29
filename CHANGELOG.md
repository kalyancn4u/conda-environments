# Changelog

All notable changes to this repository are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- `07-geospatial.yml` (`py312-geo`) — GeoPandas/Shapely/PyProj/Fiona + GDAL/rasterio
  vector & raster stack, plus folium/contextily/mapclassify and geoalchemy2.
- `08-timeseries.yml` (`py312-ts`) — Prophet/cmdstanpy, sktime, statsforecast,
  statsmodels, and ruptures for forecasting & change-point detection.
- Both added to the verifier (`verify-env.py`), the `test-environments` CI matrix,
  and the `update-lockfiles` workflow; documented in the READMEs and GUIDE.
- `python/3.12/GUIDE.md` — a complete, beginner-friendly walkthrough documenting every
  file in the 3.12 tree and every artifact it generates; linked from both READMEs.
- README section on building an "all-in-one" environment by iteratively layering the
  environment YAMLs with `conda env update`, including the `--prune`/TensorFlow caveats
  and an honest pros/cons analysis.

### Changed
- `02-ml.yml` — added clustering/manifold (`hdbscan`, `umap-learn`), extra estimators
  (`mlxtend`, `skops`), and interpretability (`eli5`), surfaced by auditing 60 legacy
  environment files against the repo.

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
