# conda / mamba vs. uv — which tool, and when (a beginner's guide)

> **The one-line answer:** use **conda/mamba** to build rich *development & scientific*
> environments (they install Python **and** non-Python system libraries), and use **uv**
> to build fast, slim, fully-pinned *Python-only* environments for **production and CI/CD**.
> This repo gives you both: conda YAMLs + lockfiles for dev, and `requirements.txt` files
> for uv in production.

No prior knowledge assumed. Read once, keep as a reference.

---

## 1. Two different jobs

Installing "the dependencies" actually splits into two very different problems:

| | **Python packages** | **Native / system libraries** |
|---|---|---|
| Examples | `pandas`, `fastapi`, `torch` | GDAL, CUDA, MKL, GEOS, a C/C++ compiler, `libjpeg` |
| Where they come from | **PyPI** (pip/uv) | the OS, or **conda-forge** |
| Who can install them | pip, uv, **conda** | **conda**, or your OS package manager (`apt`, …) |

- **pip / uv** install **only Python packages from PyPI.** If a Python package needs a
  native library, pip expects it to be *bundled in a wheel* or *already on the system*.
- **conda / mamba** install **both** Python packages **and** the native libraries, from
  **conda-forge**, on Windows/macOS/Linux — no compiler needed. That's why data-science
  stacks (GDAL, CUDA, OpenCV) are so much easier with conda.

---

## 2. The tools, in plain words

- **conda** — the original environment & package manager. Handles Python + native libs.
- **mamba** — a **faster** drop-in replacement for the `conda` command (same job, quicker).
- **conda-forge** — the community **channel** (the "app store") this repo installs from.
- **pip** — the standard installer for **PyPI** (Python-only) packages.
- **uv** — a **very fast** modern replacement for pip + venv + pip-tools, written in Rust.
  Same PyPI world as pip, but dramatically faster and with a built-in **resolver/locker**.

> Analogy: **conda/mamba** is a *full hardware store* (lumber, pipes, wiring — everything a
> build needs). **uv** is an *express Python parts counter* — only Python parts, but you're
> in and out in seconds.

---

## 3. When to use which

### Use conda / mamba when…
- You need **non-Python system libraries**: GDAL/GEOS (geospatial), CUDA (GPU),
  MKL/BLAS, `cmdstan` (Prophet), a compiler toolchain.
- You want **one command** to get a working scientific stack on any OS.
- You're doing **interactive development, notebooks, research**.
- → This is the whole `environments/*.yml` + `lockfiles/` side of this repo.

### Use uv (with `requirements.txt`) when…
- Your app's dependencies are **all on PyPI as wheels** (typical web/API/service apps).
- You're building a **production container** and want it **small, fast, reproducible**.
- You're in **CI/CD** and every second and megabyte counts.
- → This is the `lockfiles/requirements/*.txt` side of this repo.

### Rule of thumb
> **Develop with conda. Ship with uv** — *if* the service's dependencies are pure-PyPI.
> If production still needs GDAL/CUDA/etc., ship the conda environment (or a conda-based
> image) instead.

---

## 4. "CD uses uv — right?" — yes, and here's why

In **Continuous Deployment**, you repeatedly build an image and deploy it. What matters
there is **speed, size, and exact reproducibility**:

- **Speed:** uv resolves and installs in **seconds** (often 10–100× faster than pip).
  Faster pipelines = faster, cheaper deploys.
- **Reproducibility:** uv compiles a **fully-pinned** `requirements.txt` (every package +
  version + hash). The production image is byte-for-byte the same every build.
- **Size:** a uv/pip venv with only the PyPI wheels you need is far smaller than a full
  conda environment (which carries system libraries, compilers, etc.).

A typical Dockerfile for a Python service:

```dockerfile
FROM python:3.12-slim
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv
COPY lockfiles/requirements/04-web.txt requirements.txt
# --system installs into the image's Python; --no-cache keeps the layer slim
RUN uv pip install --system --no-cache -r requirements.txt
COPY . /app
CMD ["uvicorn", "app:app", "--host", "0.0.0.0"]
```

**But** — CD uses conda instead when the service genuinely needs conda-only native libs
(e.g. a GDAL-heavy geoprocessing worker, or a CUDA build pinned to a driver). Then you
ship a conda-based image. **uv is the default for CD *because most services are pure
Python* — not a universal law.**

---

## 5. How the two artifacts in this repo relate

```text
environments/04-web.yml          (INTENT, conda names, unpinned)
   │
   ├── conda-lock ─────────────►  lockfiles/linux-64/04-web.conda.lock   (DEV: exact,
   │                                                                       incl. system libs)
   └── (PyPI names) uv compile ─►  lockfiles/requirements/04-web.txt      (PROD: exact,
                                                                           PyPI wheels only)
```

- The **conda lockfile** reproduces the full **development** environment (Python + native).
- The **uv `requirements.txt`** reproduces a slim **production** environment (PyPI only).

They are **not identical** and cannot be — a conda env contains packages that don't exist
on PyPI (and vice-versa). Each targets a different stage.

---

## 6. Name gotcha: conda name ≠ PyPI name

The same library is often named differently in each world. The `requirements.txt` files
use **PyPI** names; the conda YAMLs use **conda-forge** names.

| conda-forge | PyPI (used in requirements.txt) | import |
|-------------|--------------------------------|--------|
| `pytorch` | `torch` | `torch` |
| `opencv` | `opencv-python-headless` | `cv2` |
| `feature_engine` | `feature-engine` | `feature_engine` |
| `redis-py` | `redis` | `redis` |
| `docker-py` | `docker` | `docker` |
| `beautifulsoup4` | `beautifulsoup4` | `bs4` |

(For servers we prefer `opencv-python-headless` — no GUI libs — over `opencv-python`.)

---

## 7. Caveats — where uv/requirements.txt is *not* a drop-in

Some environments here rely on conda's native-library superpowers and **do not translate
cleanly to PyPI**:

- **`07-geospatial` (GDAL/rasterio/fiona):** the PyPI GDAL story is painful (it needs
  system GDAL headers/libraries to build). Its `requirements.txt` is provided for
  reference but you typically want the **conda** environment (or system GDAL) in production.
- **`08-timeseries` (Prophet):** Prophet compiles Stan models via `cmdstan`, a native
  toolchain conda provides. On PyPI you must set that up yourself.
- **`06-tensorflow` / GPU:** GPU builds and CUDA come from conda (or vendor wheels); the
  plain `requirements.txt` is CPU-oriented.

For these, prefer conda in production, or accept extra system setup. Each affected
`requirements.txt` carries a header note.

---

## 8. Quick commands

```bash
# DEV (conda/mamba): create a full environment
mamba env create -f python/3.12/environments/04-web.yml

# PROD (uv): install the pinned PyPI set into the current venv/image
uv pip install -r python/3.12/lockfiles/requirements/04-web.txt

# Regenerate a pinned requirements.txt from its intent (.in) with uv's resolver
uv pip compile python/3.12/lockfiles/requirements/04-web.in -o python/3.12/lockfiles/requirements/04-web.txt
```

---

## 9. Glossary

- **PyPI** — the Python Package Index; where pip/uv download from.
- **conda-forge** — the community conda channel this repo uses.
- **wheel** — a pre-built, ready-to-install Python package (no compiler needed).
- **resolver** — the component that picks a mutually-compatible set of versions.
- **pin / lock** — record exact versions so installs are reproducible.
- **`.in` vs `.txt`** — `requirements.in` is loose *intent*; `uv pip compile` turns it into
  a fully-pinned `requirements.txt`.
- **CD** — Continuous Deployment: automated build-and-ship pipelines.
