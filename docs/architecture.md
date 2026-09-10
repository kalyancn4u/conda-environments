# Architecture

This document explains *why* the repository is shaped the way it is. The goal is a
structure that stays maintainable for years and across multiple Python versions.

## Design goals

1. **Modularity** — each environment addresses one concern. Small environments
   solve faster, conflict less, and are easier to reason about than one giant env.
2. **Reproducibility** — human-readable intent (`*.yml`) is separated from exact,
   machine-generated state (lockfiles).
3. **Maintainability** — minimal pinning and clear comments so upgrades are cheap.
4. **Portability** — CPU-only definitions solve identically on Linux, Windows, and
   Apple Silicon; hardware-specific concerns are documented, not hard-coded.

## Directory layout & the version prefix

```text
scripts/                 # shared, version-agnostic helpers (create/update/verify/
                         #   doctor/…) + uv-to-conda — pass -p <ver> to target a tree
python/
├── 3.10/               # validated parity tree (linux-64 locks + uv requirements)
├── 3.12/               # primary, fully-locked reference
│   ├── environments/   # modular definitions (the source of truth for intent)
│   ├── templates/      # opinionated starting points to fork per project
│   ├── examples/       # uv-to-conda sample inputs + generated environment.yml
│   └── lockfiles/      # generated, per-platform, exact-rebuild artifacts
├── 3.13/               # structural parity; lockfiles generated on demand
└── 3.14/               # structural parity; heavy stacks may lag; locks on demand
```

The `python/<version>/` prefix is the key structural decision. Everything that is
version-specific lives under it, so introducing a new Python version is a **copy + re-solve**
— exactly how [`3.10`](../python/3.10/), [`3.13`](../python/3.13/), and
[`3.14`](../python/3.14/) were each added:

```bash
cp -r python/3.12 python/3.15
# bump `python=3.12.*` -> `python=3.15.*` and `py312-*` -> `py315-*`, then re-solve
```

No shared/global files need to change, and multiple Python versions coexist without
interfering. Cross-cutting documentation (this `docs/` tree) stays version-agnostic
and references version-specific details where needed. **A newer Python only reaches
parity once conda-forge has builds for the whole stack** — so a very fresh version (3.14
today) ships the structure with pins bumped, while its heaviest environments wait on
upstream and its lockfiles are generated on demand.

## The environment matrix

Every file in `python/3.12/environments/`, what it contains, and why it stands alone:

| File | Env name | Concern | Headline packages | CPU/GPU | Platforms | Why it is separate |
|------|----------|---------|-------------------|---------|-----------|--------------------|
| `01-core.yml` | `py312-core` | Scientific-Python daily driver | jupyterlab, numpy, pandas, polars, pyarrow, scipy, scikit-learn, statsmodels, matplotlib, seaborn, plotly, duckdb, sqlalchemy, requests, httpx | CPU | linux-64 · win-64 · osx-arm64 | The 80–90% case; kept small and stable so it always solves fast |
| `02-ml.yml` | `py312-ml` | Classical / tabular ML | xgboost, lightgbm, catboost, optuna, mlflow, shap, eli5, imbalanced-learn, category_encoders, feature_engine, hdbscan, umap-learn, mlxtend, skops | CPU | linux-64 · win-64 · osx-arm64 | Boosting/tuning stacks are heavy and evolve on their own cadence |
| `03-deep-learning.yml` | `py312-dl` | Deep learning (PyTorch) | pytorch, torchvision, torchaudio, lightning, transformers, datasets, accelerate, sentence-transformers, spacy, opencv, timm, onnx, onnxruntime | CPU | linux-64 · win-64 · osx-arm64 | Large binary deps; **kept apart from TensorFlow** (see below) |
| `04-web.yml` | `py312-web` | Web APIs & data apps | fastapi, flask, django, uvicorn, gunicorn, streamlit, gradio, dash, pydantic, alembic, celery, redis-py | CPU | linux-64 · win-64* · osx-arm64 | Server/runtime concerns on a different release cadence |
| `05-tools.yml` | `py312-tools` | Developer tooling | pytest, pytest-cov, coverage, ruff, black, mypy, pre-commit, tox, nox, playwright, selenium, scrapy, cookiecutter, docker-py | CPU | linux-64 · win-64 · osx-arm64 | A "toolbox" independent of any project's runtime |
| `06-tensorflow.yml` | `py312-tf` | Deep learning (TensorFlow) | tensorflow, keras, tensorboard | CPU | linux-64 · **osx-arm64** | **Isolated from PyTorch** to avoid protobuf/abseil/numpy contention; no conda-forge win-64 build |
| `07-geospatial.yml` | `py312-geo` | Geospatial (vector + raster) | geopandas, shapely, pyproj, fiona, gdal, rasterio, contextily, folium, mapclassify, geoalchemy2 | CPU | linux-64 · win-64 · osx-arm64 | GDAL/GEOS/PROJ stack is heavy and best pinned together |
| `08-timeseries.yml` | `py312-ts` | Time series & forecasting | prophet, cmdstanpy, sktime, statsforecast, statsmodels, ruptures | CPU | linux-64 · win-64 · osx-arm64 | Prophet/Stan compilation is heavy; forecasting stack evolves independently |
| `98-legacy.yml` | `py312-legacy` | Deprecated / compatibility | *(mostly commented out)* gensim, nltk, docopt… | CPU | n/a | Reference/documentation only — records what was removed and its replacement |

\* `gunicorn` in `04-web` is POSIX-only; on Windows use `uvicorn`/`waitress`. Full
platform/CUDA details are in [compatibility.md](compatibility.md).

Templates (`minimal`, `data-science`, `mlops`, `llm`) are **compositions** for common
personas — convenience supersets you fork and trim, not additional modules to maintain:

| Template | Env name | For |
|----------|----------|-----|
| `templates/minimal.yml` | `py312-min` | The smallest useful clean slate to build a new project on |
| `templates/data-science.yml` | `py312-ds` | A single env combining `01-core` + the most-used `02-ml` pieces |
| `templates/mlops.yml` | `py312-mlops` | Orchestration & ops: Apache Airflow, MLflow, wandb, DVC, cloud SDKs |
| `templates/llm.yml` | `py312-llm` | LLM app development: transformers, sentence-transformers, faiss, a small API server |
| `templates/all-in-one-pytorch.yml` | `py312-all-pytorch` | Kitchen-sink convenience env unioning the modular stacks with the **PyTorch** DL framework; heavy & conflict-prone — a scratch env, not for production |
| `templates/all-in-one-tflow.yml` | `py312-all-tflow` | Same kitchen sink but with **TensorFlow/Keras** instead of PyTorch (the two can't coexist); no conda-forge win-64 TF build |

### Why split TensorFlow and PyTorch?

Both frameworks pin low-level libraries aggressively (`protobuf`, `abseil`, `numpy`,
CUDA runtimes). Co-installing them frequently produces an unsolvable environment or a
silently downgraded one. Splitting them means each solves cleanly and upgrades on its
own schedule. Few real projects need both frameworks in a single interpreter; those
that do can compose the two YAMLs deliberately and accept the tighter constraints.

### Why Airflow/SageMaker live in a template, not a module

Apache Airflow brings a very large, opinionated dependency tree (schedulers,
providers, web server) and is POSIX-oriented. Bundling it into `04-web` would make an
otherwise fast environment slow and fragile. It belongs in a dedicated environment or
container — hence `templates/mlops.yml`.

## Intent vs. lock: the two-layer model

```text
environments/01-core.yml   (INTENT: what we want, minimally pinned)
        │  conda-lock / conda env export
        ▼
lockfiles/<platform>/01-core.lock   (STATE: exact versions+builds+hashes)
```

- **YAML** is what humans edit and review. It expresses intent with as few pins as
  possible so the solver can pick compatible, up-to-date versions.
- **Lockfiles** are generated per platform for byte-for-byte reproducible rebuilds
  (CI, production). They are never hand-edited. See
  [upgrade-strategy.md](upgrade-strategy.md) and the `update-lockfiles` workflow.

This separation is what lets us have *both* "avoid unnecessary pinning" *and*
"fully reproducible" without contradiction.
