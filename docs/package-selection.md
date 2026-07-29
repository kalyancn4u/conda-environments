# Package Selection Philosophy

Every include and exclude in this repository follows a small set of rules. This
document makes them explicit so contributions stay consistent.

## The rules

1. **Prefer conda-forge.** A package must resolve from `conda-forge`. Use `pip` only
   when there is no conda-forge distribution (e.g. `tiktoken`, `sagemaker`), and say
   so in a comment.
2. **One tool per job.** Avoid redundant packages that solve the same problem
   (`ruff` replaces `flake8` + `isort` + `pyupgrade`; `httpx` covers modern HTTP).
3. **Avoid abandoned projects.** If upstream is unmaintained, prefer a living
   alternative and record the swap in [upgrade-strategy.md](upgrade-strategy.md).
4. **Minimal pinning.** Pin only `python` by default. Add a version bound only for a
   concrete reason (a known-bad release, an ABI requirement) — and comment *why*.
5. **CPU by default.** No CUDA/GPU packages in the YAMLs; GPU is documented in
   [compatibility.md](compatibility.md).
6. **Never mix conda + pip for the same package.** This was the top cause of breakage
   in the source environment.

## What "essential" means for `01-core`

The core environment targets the ~80–90% of daily work: load data, explore, model
lightly, visualize, and share via notebooks. That justifies numpy/pandas/polars,
pyarrow, scipy, scikit-learn, statsmodels, the plotting trio, DuckDB, SQLAlchemy, the
HTTP/parsing set, and JupyterLab. Anything heavier (boosting, deep learning, web
serving) is a different concern and lives elsewhere — that is what keeps core fast.

## Notable deliberate choices

| Choice | Rationale |
|--------|-----------|
| `polars` **and** `pandas` in core | They complement each other; polars for speed/large data, pandas for ecosystem compatibility. |
| `duckdb` in core | In-process analytical SQL over Parquet/Arrow without a server — increasingly a default tool. |
| `httpx` alongside `requests` | Async support and a modern API; `requests` kept for ubiquity. |
| `ruff` in tools | One fast tool replacing several linters/formatters. |
| `beautifulsoup4`, never `bs4` | `bs4` on PyPI is an empty shim; the real package is `beautifulsoup4`. |
| `redis-py` (imports as `redis`) | The conda-forge package name differs from the import name — noted in the YAML. |
| `feature_engine` (conda) = `feature-engine` (pip) | conda-forge uses the **underscore**; the PyPI/pip name uses a hyphen. Using the hyphen in a conda YAML fails to solve. |
| `playwright` via **pip** | The conda-forge `playwright` package is the browser *driver*, not the importable Python API — the bindings come from PyPI. |
| Keras 3 over `tf-keras` | Multi-backend Keras is the supported path; the shim is legacy. |

### Package-naming quirks (conda-forge vs. PyPI)

A recurring footgun: a package's conda-forge name, its PyPI/pip name, and its **import**
name can all differ. Get the conda-forge name wrong and the environment simply won't solve.

| conda-forge name | PyPI / pip name | import name |
|------------------|-----------------|-------------|
| `feature_engine` | `feature-engine` | `feature_engine` |
| `beautifulsoup4` | `beautifulsoup4` | `bs4` |
| `redis-py` | `redis` | `redis` |
| `docker-py` | `docker` | `docker` |
| `pytorch` | `torch` | `torch` |
| `opencv` | `opencv-python` | `cv2` |

## What we deliberately excluded (and why)

- **stdlib backports** (`dataclasses`, `typing`, `backports.strenum`) — present in the
  source env, but on Python 3.12 they are redundant and can shadow the standard library.
- **Build toolchains** (`m2w64-*`, `mingw-w64-*`, `msys2-*`) — these are compiler
  suites that leaked into the source `base` env; they are never runtime dependencies.
- **CUDA runtime packages** (`cuda-*`, `libcublas*`, ...) — pulled into `base` in the
  source, making it non-portable. Install per project when GPU is required.
- **Ancient/incompatible pins** — e.g. `transformers==2.1.1`; see
  [`99-upgrade-candidates.md`](../python/3.12/environments/99-upgrade-candidates.md).
- **`albumentations`** — its current conda-forge build is broken: it pulls `albucore`,
  which hard-imports `simsimd`, a dependency conda-forge does not reliably provide, so
  `import albumentations` fails. Pip-installing it would drag in `opencv-python-headless`
  and clash with conda `opencv`. Add it in a project venv (`pip install albumentations`)
  if you need it.
- **`xlrd`** — moved to `98-legacy.yml`; it reads only the obsolete `.xls` format.

## Adding a package: the checklist

1. Is it on conda-forge? (If not, is `pip` truly required?)
2. Does an existing environment already cover this concern?
3. Is it actively maintained?
4. Does it need a version pin? If yes, why — write the comment.
5. Is it CPU-only? (Move GPU specifics to docs.)
6. Keep the list alphabetical within its comment group.
