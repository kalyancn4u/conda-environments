# The Complete Beginner's Guide to `python/3.10/`

> **Who this is for:** someone who has *never* used conda (or has used it only by
> copy-pasting commands) and wants to understand **what every single file in this
> folder is, what it does, when to touch it, and what new things ("artifacts") appear
> when you use it.** No prior knowledge assumed. Read top to bottom once, then keep it
> as a reference.

If you only remember one sentence: **the `.yml` files describe environments you *want*,
the scripts *build and manage* them for you, the lockfiles *freeze* them for perfect
reproducibility, and GitHub Actions *checks* that all of it actually works.**

---

## Part 0 — Five words you need first

Before the files make sense, five plain-language definitions:

| Word | Plain meaning | Everyday analogy |
|------|---------------|------------------|
| **Conda** | A program that installs Python + libraries and keeps sets of them separate. | A kitchen manager who sets up separate, non-conflicting work-stations. |
| **Environment** | One isolated, self-contained set of Python + packages with a name (e.g. `py310-core`). | One work-station with exactly the tools that job needs. |
| **Package** | A reusable library you install (e.g. `pandas`, `numpy`). | One tool (a whisk, a knife). |
| **Channel** | The online store conda downloads packages from. This repo uses **`conda-forge`**. | The single trusted supplier we buy every tool from. |
| **YAML** (`.yml`) | A simple text format that lists what an environment should contain. | The shopping list for one work-station. |

Two more that come up constantly:

- **conda vs. mamba:** `mamba` is a faster, drop-in replacement for `conda`. Anywhere
  this guide says `conda`, you can type `mamba` and it works the same, just quicker. The
  scripts here use `mamba` automatically if you have it.
- **CPU vs. GPU:** Every environment here installs the **CPU** version of things (works
  on any laptop). GPU (NVIDIA graphics-card acceleration) is optional and explained
  separately in [`../../docs/compatibility.md`](../../docs/compatibility.md) — you do
  **not** need it to start.

---

## Part 1 — The map (what lives where)

```text
python/3.10/
├── README.md            ← short "front page" for this folder
├── GUIDE.md             ← THIS file: the long, beginner-friendly explanation
│
├── environments/        ← the real deliverable: definitions of each environment
│   ├── 01-core.yml            everyday data work (start here)
│   ├── 02-ml.yml              classical machine learning
│   ├── 03-deep-learning.yml   PyTorch + Hugging Face (neural networks)
│   ├── 04-web.yml             web apps & APIs
│   ├── 05-tools.yml           developer tools (testing, linting)
│   ├── 06-tensorflow.yml      TensorFlow (kept separate on purpose)
│   ├── 07-geospatial.yml      maps & geodata (GeoPandas, GDAL, rasterio)
│   ├── 08-timeseries.yml      forecasting (Prophet, sktime, statsforecast)
│   ├── 98-legacy.yml          old/retired packages — reference only, NOT for use
│   └── 99-upgrade-candidates.md   a report: what to upgrade/replace/remove & why
│
├── templates/           ← ready-made "starter kits" you copy for a new project
│   ├── minimal.yml            the smallest useful environment
│   ├── data-science.yml       core + ML combined into one
│   ├── mlops.yml              orchestration & experiment-tracking (Airflow, MLflow…)
│   ├── llm.yml                large-language-model app development
│   ├── all-in-one-pytorch.yml kitchen-sink env, PyTorch deep-learning stack
│   └── all-in-one-tflow.yml   kitchen-sink env, TensorFlow deep-learning stack
│
├── scripts/             ← helper programs so you don't memorize conda commands
│   ├── create-env.sh / .ps1   build an environment from a .yml
│   ├── update-env.sh / .ps1   update an existing environment to match its .yml
│   ├── export-env.sh          save an exact snapshot of an environment
│   ├── clean-env.sh           free disk space (safe cache cleanup)
│   ├── compare-envs.sh / .ps1 diff two environments / find upgradable packages
│   ├── verify-env.py          quick check that an environment's packages import
│   └── test-env.sh / .ps1     reproduce the CI build+verify in a Docker container
│
└── lockfiles/           ← auto-generated "exact recipes" for perfect rebuilds
    ├── linux-64/  win-64/  osx-arm64/   (one folder per operating system)
    └── README.md
```

**`.sh` vs `.ps1`:** `.sh` files are for **Linux and macOS** (they run in a program
called *bash*). `.ps1` files are for **Windows PowerShell**. They do the *same jobs* —
pick the one matching your computer. `.py` files run anywhere Python does.

---

## Part 2 — The environment files (`environments/`) — the heart of the repo

Each `.yml` here is a **recipe for one environment**. Opening one, you'll see three parts:

```yaml
name: py310-core        # the environment's name (what you 'conda activate')
channels:               # where to download from — always just conda-forge
  - conda-forge
dependencies:           # the list of packages to install
  - python=3.10.*
  - numpy
  - pandas
  ...
```

- `name:` — the label you'll use to switch into it later.
- `channels:` — always exactly `conda-forge` (our single trusted supplier).
- `dependencies:` — the packages. `python=3.10.*` means "any Python 3.10.x". Most other
  packages have **no version number on purpose** — that lets conda pick the newest
  compatible versions, which keeps upgrades easy. (The reasoning is in
  [`../../docs/package-selection.md`](../../docs/package-selection.md).)

You do **not** run a `.yml` file directly. You hand it to conda (or to a script), which
reads the list and installs everything. That act of installing **creates an
environment** — see [Part 6](#part-6--every-artifact-that-gets-generated).

### File-by-file

| File | Creates env | What it's for | Create it when you want to… |
|------|-------------|---------------|-----------------------------|
| **`01-core.yml`** | `py310-core` | The daily driver: Jupyter, NumPy, Pandas, Polars, SciPy, Matplotlib/Seaborn/Plotly, scikit-learn, DuckDB, requests/httpx, etc. Covers ~80–90% of everyday work. | Explore data, run notebooks, make charts, do light modeling. **Start here.** |
| **`02-ml.yml`** | `py310-ml` | Classical machine learning: XGBoost, LightGBM, CatBoost, Optuna (tuning), MLflow (tracking), SHAP (explanations), feature-engineering tools. | Train tabular ML models and track experiments. |
| **`03-deep-learning.yml`** | `py310-dl` | Neural networks the **PyTorch** way: PyTorch, Lightning, the Hugging Face stack (Transformers, Datasets, Accelerate), spaCy, OpenCV, ONNX. CPU builds. | Build/fine-tune neural networks, work with transformer models. |
| **`04-web.yml`** | `py310-web` | Web development: FastAPI, Flask, Django, Streamlit, Gradio, Dash, plus servers (Uvicorn/Gunicorn) and helpers (Pydantic, Alembic, Celery, Redis client). | Build an API, a dashboard, or a web app. |
| **`05-tools.yml`** | `py310-tools` | Developer tooling: pytest, coverage, ruff (linter), black (formatter), mypy (type checks), pre-commit, tox/nox, Selenium/Playwright (browser automation), Scrapy. | Test, lint, format, or automate a browser — a "toolbox" env. |
| **`06-tensorflow.yml`** | `py310-tf` | **TensorFlow + Keras**, deliberately kept in its own environment (TensorFlow and PyTorch pin conflicting low-level libraries, so mixing them breaks). | Work specifically with TensorFlow/Keras. ⚠️ **Windows note below.** |
| **`07-geospatial.yml`** | `py310-geo` | **Maps & geographic data**: GeoPandas, Shapely, PyProj, Fiona (vector), GDAL + rasterio (raster), plus folium/contextily for mapping. | Work with shapefiles, coordinates, maps, or satellite/raster data. |
| **`08-timeseries.yml`** | `py310-ts` | **Forecasting**: Prophet, sktime, statsforecast, statsmodels, plus ruptures for change-point detection. | Forecast future values, or detect shifts/seasonality in time-ordered data. |
| **`98-legacy.yml`** | (mostly none) | A **documented graveyard**. Almost every line is "commented out" (disabled) with a note explaining why a package is retired and what replaces it. It is *reference material*, not a working environment. | Understand what was removed and why. You will rarely, if ever, create this. |

> ⚠️ **`06-tensorflow.yml` on Windows:** our supplier (conda-forge) does **not** publish a
> Windows build of TensorFlow. On Windows, install it with `pip` instead — the exact
> commands are inside the file's comments and in
> [`../../docs/compatibility.md`](../../docs/compatibility.md). On Linux/macOS it just works.

### The one report: `99-upgrade-candidates.md`

Not an environment — it's a **written analysis** (Markdown). It's the "doctor's report"
produced from studying the original messy environment this project replaced. It sorts
packages into categories — ✅ safe to upgrade, ⚠️ upgrade carefully, 🔁 replace with a
modern tool, 🗑️ remove, ☠️ broken/end-of-life — and explains the reasoning for each.
Read it to understand *why* the environments look the way they do.

---

## Part 3 — The templates (`templates/`) — starter kits to copy

Templates are **not** part of the numbered core set. They're convenient, pre-mixed
starting points you **copy and rename** when beginning a brand-new project, then trim to
what you actually need.

| File | Creates env | Best when you… |
|------|-------------|----------------|
| **`minimal.yml`** | `py310-min` | Want the smallest possible clean slate (just Python + a couple of niceties) and will add packages yourself. |
| **`data-science.yml`** | `py310-ds` | Prefer **one** environment that combines the core stack *and* the most-used ML tools, instead of juggling `01-core` + `02-ml`. |
| **`mlops.yml`** | `py310-mlops` | Need workflow orchestration & experiment ops: Apache Airflow, MLflow, Weights & Biases, DVC, cloud SDKs. (Heavy; Airflow is Linux/macOS-oriented.) |
| **`llm.yml`** | `py310-llm` | Are building with large language models: Transformers, Sentence-Transformers, embeddings/vector search, plus a small API server. |
| **`all-in-one-pytorch.yml`** | `py310-all-pytorch` | Want *one* env with (almost) everything and **PyTorch** as the DL framework — core + ML + PyTorch + web + tools + geospatial + time series. **Heavy & conflict-prone;** best as a scratch env, lock it once it works. |
| **`all-in-one-tflow.yml`** | `py310-all-tflow` | Same kitchen sink but with **TensorFlow/Keras** instead of PyTorch (the two can't coexist). Heavy & conflict-prone; no conda-forge win-64 TF build (pip on Windows). |

**How to use a template:** copy it into your own project, change the `name:`, delete
what you don't need, add what you do, then create it with the same `create-env` script
you'd use for any environment.

---

## Part 4 — The scripts (`scripts/`) — your helpers

Scripts exist so you don't have to memorize conda's flags. Each does one job. Below,
"run it like this" shows the Linux/macOS (`.sh`) form; on Windows use the matching
`.ps1` with `.\` in front (e.g. `.\scripts\create-env.ps1 01-core`).

> **Where do I run these?** In a terminal, from inside the `python/3.10/` folder (or
> give full paths). On Windows that's **PowerShell**; on Mac/Linux it's **Terminal**.

### `create-env.sh` / `create-env.ps1` — build an environment

**What it does:** reads an environment `.yml` and installs everything in it, creating a
brand-new named environment. Uses `mamba` automatically if available.

```bash
./scripts/create-env.sh 01-core          # builds the py310-core environment
```
You can pass a bare name (`01-core`), or a path to any `.yml` (including a template).
**Result:** a new environment exists; the script prints the `conda activate …` command
to switch into it.

### `update-env.sh` / `update-env.ps1` — sync an environment to its recipe

**What it does:** you edited a `.yml` (added or removed a package); this makes the
already-built environment match it again. It uses `--prune`, meaning packages you
*removed* from the file are also removed from the environment — so the environment stays
an exact mirror of its recipe.

```bash
./scripts/update-env.sh 01-core
```

### `export-env.sh` — save an exact snapshot

**What it does:** takes an environment that's currently installed and writes out an exact
record of *every* package and version in it — a snapshot for "it works right now, capture
it." Produces three files in an `exports/` folder:

| Output file | What it is |
|-------------|------------|
| `<env>-frozen.yml` | Full list with exact versions **and** build strings (most precise, this machine). |
| `<env>-nobuild.yml` | Versions only, no build strings (a bit more portable across machines). |
| `<env>-explicit.txt` | A plain list of exact download URLs for a perfect rebuild. |

```bash
./scripts/export-env.sh py310-core
```
> These snapshots are **throwaway** and Git ignores them. For *shared, official*
> reproducibility, use lockfiles ([Part 5](#part-5--the-lockfiles-lockfiles)) instead.

### `clean-env.sh` — reclaim disk space (safe)

**What it does:** conda keeps downloaded package files cached; over time that eats gigabytes.
This clears the **cache only** — it never deletes your environments.

```bash
./scripts/clean-env.sh          # DRY RUN: shows what it *would* delete
./scripts/clean-env.sh --yes    # actually delete the cache
```

### `compare-envs.sh` / `compare-envs.ps1` — diff two environments / find upgrades

**Two modes:**

```bash
./scripts/compare-envs.sh py310-core py310-ds     # list packages that differ between two envs
./scripts/compare-envs.sh --outdated py310-core   # list packages that COULD be upgraded
```
Useful to answer "what's actually different between these two?" or "am I behind on anything?"

### `verify-env.py` — quick health check

**What it does:** a fast smoke test. It tries to `import` the headline packages of an
environment and reports ✅/❌ for each, plus a note if your Python isn't 3.10. It does
**not** test that the packages *work fully* — just that they load without errors, which
catches most broken installs.

```bash
conda activate py310-core
python scripts/verify-env.py --env core     # check the core set
python scripts/verify-env.py --all          # check every known set
python scripts/verify-env.py --packages numpy pandas   # check your own list
```
Example of what a healthy run looks like:
```text
OK  python 3.10.x (as expected)
------------------------------------------------------------
[core]
OK  numpy      2.x
OK  pandas     2.x
...
SUCCESS: all imports succeeded.
```
If a package is broken you'll see `!!  <name>  IMPORT FAILED: …` and the script exits
with an error — which is why the CI can use it as a pass/fail gate.

### `test-env.sh` / `test-env.ps1` — reproduce CI in Docker

**What it does:** builds an environment **and** runs `verify-env.py` inside the same
`condaforge/miniforge3` Docker container that GitHub Actions uses — so "passes on my
machine" means the same thing as "passes in CI." Requires Docker.

```bash
./scripts/test-env.sh 01-core      # one environment  (Windows: .\scripts\test-env.ps1 01-core)
./scripts/test-env.sh --all        # all of them
```
A cached Docker volume keeps downloaded packages between runs, so repeats are fast.

---

## Part 5 — The lockfiles (`lockfiles/`)

**The problem they solve:** the `.yml` files intentionally *don't* pin most versions, so
two people creating `py310-core` a month apart might get slightly different versions. Most
of the time that's fine and good (you get updates). But sometimes you need **exactly the
same environment, byte-for-byte** — for a production server, or to reproduce a result.

**A lockfile is that exact recipe.** It records every package with its precise version,
build, and a checksum. Rebuilding from a lockfile gives an *identical* environment every
time, on that operating system.

```text
lockfiles/
├── linux-64/     ← exact recipes for Linux
├── win-64/       ← exact recipes for Windows
└── osx-arm64/    ← exact recipes for Apple-Silicon Macs
```

Why one folder per operating system? Because the exact low-level packages differ per OS,
so each needs its own frozen recipe.

**You do not write these by hand.** They are generated — either by the
`update-lockfiles` GitHub workflow ([Part 7](#part-7--the-automation-githubworkflows)) or
locally with a tool called `conda-lock`. The `README.md` in that folder shows the exact
command. Right now the platform folders contain only a placeholder file (`.gitkeep`) so
they exist in Git until the first real lockfiles are generated.

**Intent vs. lock — the mental model:**
```text
01-core.yml  (what we WANT, loosely pinned)  →  generate  →  linux-64/01-core.lock (EXACT)
```

---

## Part 6 — Every artifact that gets *generated*

You asked for completeness, so here is **everything that comes into existence** when you
use this folder, where it goes, and whether Git keeps it:

| Artifact | Created by | Where it lives | Tracked in Git? |
|----------|-----------|----------------|-----------------|
| **A conda environment** (the actual installed Python + packages) | `create-env` / `conda env create` | Inside conda's own folder on your disk (e.g. `…/miniconda3/envs/py310-core`), **not** in this repo | No — it's on your machine only |
| **Snapshot files** (`*-frozen.yml`, `*-nobuild.yml`, `*-explicit.txt`) | `export-env.sh` | An `exports/` folder you choose | No — Git ignores them (see `.gitignore`) |
| **Lockfiles** (`*.conda.lock`) | `update-lockfiles` workflow or `conda-lock` | `lockfiles/<os>/` | **Yes** — these are meant to be shared |
| **A pull request refreshing lockfiles** | `update-lockfiles` workflow | On GitHub | It proposes tracked changes |
| **CI pass/fail + badges** | `validate` & `test-environments` workflows | GitHub "Actions" tab; badges on the README | Status only, not files |
| **Downloaded package cache** | conda, during any install | conda's cache folder | No — cleared by `clean-env.sh` |

The key idea: **this repository stores recipes and checks (text files). The heavy
installed environments live on your computer, created on demand from those recipes.**
That's what keeps the repo small, portable, and reproducible.

---

## Part 7 — The automation (`.github/workflows/`)

These live one level up (in the repo root's `.github/`) but they act on *this* folder, so
here's what they do in plain terms. They run automatically on GitHub whenever files change.

| Workflow | When it runs | What it checks / produces (in plain words) |
|----------|--------------|--------------------------------------------|
| **`validate.yml`** | On every change to a `.yml` | "Are these environment files well-formed and do they follow our rules?" (valid YAML, `conda-forge`-only, has a Python pin). Fast. |
| **`test-environments.yml`** | On changes under `python/**` | The real proof: inside the `condaforge/miniforge3` container on the free **Linux** runner, it **builds each environment**, runs `verify-env.py`, and fails if any package was installed by *both* conda and pip (a known source of breakage). Linux-only to stay within free CI minutes. |
| **`update-lockfiles.yml`** | Weekly, or on demand | Regenerates the lockfiles and opens a pull request with the refreshed versions for you to review. |

When these pass, the green **badges** at the top of the root `README.md` light up.

---

## Part 8 — Your very first session (do exactly this)

Never done any of this? Follow these steps once:

```bash
# 1) Tell conda to use our single supplier, strictly. (One time per computer.)
conda config --add channels conda-forge
conda config --set channel_priority strict

# 2) Build the daily-driver environment. (Linux/macOS shown; Windows: .\scripts\create-env.ps1 01-core)
./scripts/create-env.sh 01-core

# 3) Switch into it.
conda activate py310-core

# 4) Confirm it's healthy.
python scripts/verify-env.py --env core

# 5) Use it — e.g. launch notebooks:
jupyter lab
```
When you're done, `conda deactivate` returns you to normal. To remove an environment
entirely later: `conda env remove -n py310-core`.

That's it — you now understand every file in `python/3.10/`, what it does, and what each
action produces.

### Where to go next (your path to mastery)

1. **The *why* behind the design** → [`docs/architecture.md`](../../docs/architecture.md).
2. **Environments & installers — conda vs. venv vs. uv, and mamba/micromamba** →
   [`docs/conda-vs-uv.md`](../../docs/conda-vs-uv.md). This is the big one: it explains
   virtual environments from scratch, when to use each tool, how production/CD differs from
   development, and how to keep uv from clobbering a conda env.
3. **Reproducibility (lockfiles), from first principles** →
   [`lockfiles/LOCKFILES-EXPLAINED.md`](lockfiles/LOCKFILES-EXPLAINED.md), then the
   command reference in [`lockfiles/README.md`](lockfiles/README.md).
4. **Why each package was chosen** → [`docs/package-selection.md`](../../docs/package-selection.md);
   **moving versions forward** → [`docs/upgrade-strategy.md`](../../docs/upgrade-strategy.md);
   **when things break** → [`docs/troubleshooting.md`](../../docs/troubleshooting.md) and
   the [`docs/faq.md`](../../docs/faq.md).

Work through those in order and you'll go from "can create an environment" to "understand
and can maintain the whole system."

---

## Mini-glossary (quick lookups)

- **Activate / deactivate** — switch into / out of an environment for your current terminal.
- **Build string** — a code identifying the exact compiled variant of a package.
- **Channel** — the online source of packages (here, always `conda-forge`).
- **CI (Continuous Integration)** — GitHub automatically running checks on every change.
- **conda-forge** — the community package channel this project standardizes on.
- **Dependency** — a package another package needs in order to work.
- **Environment** — a named, isolated set of Python + packages.
- **Lockfile** — an exact, frozen recipe for reproducing an environment identically.
- **mamba** — a faster drop-in replacement for the `conda` command.
- **Pin** — fixing a package to a specific version (this project pins as little as possible).
- **Prune** — during update, removing packages no longer listed in the recipe.
- **YAML (`.yml`)** — the simple text format used for the environment recipes.
