# Environments & installers: conda / mamba vs. venv + pip / uv

> **The one-line answer:** use **conda/mamba** to build rich *development & scientific*
> environments (they install Python **and** non-Python system libraries); use a
> **`venv`** + **pip/uv** to build fast, slim, *Python-only* environments for **production
> and CI/CD**. This repo gives you both — conda YAMLs + lockfiles for dev, and
> `requirements.txt` (installed into a venv, ideally with uv) for production.

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

- **`venv`** — Python's **built-in** module for making an **isolated environment**. It
  reuses the Python you already have and gives your project its own private package folder.
- **pip** — the standard installer for **PyPI** (Python-only) packages. Installs *into* the
  active environment (a venv, a conda env, or the system Python).
- **uv** — a **very fast** modern replacement for pip **and** venv (written in Rust). Same
  PyPI world as pip, but dramatically faster, with a built-in **resolver/locker**.
- **conda** — the original **environment & package** manager. Handles Python + native libs.
- **mamba** — a **faster** drop-in replacement for the `conda` command (same job, quicker).
- **conda-forge** — the community **channel** (the "app store") this repo installs from.

> Analogy: a **conda environment** is a *fully-stocked hardware store* delivered to your
> door — lumber, pipes, wiring, and its own generator (the Python interpreter). A **venv**
> is an *empty labelled shelf in your own garage* — it reuses your existing power (your
> installed Python) and you stock it with Python parts from PyPI. **uv** is the express
> courier that fills that shelf in seconds.

---

## 3. `venv` — the built-in baseline (start here)

A **virtual environment** is just a **folder** that isolates one project's Python packages
from every other project's, so upgrading `numpy` for project A can't break project B.

`venv` is the *standard-library* way to make one. Two things define it:

1. **It reuses your existing Python.** `python -m venv .venv` copies/links *the same Python
   you ran the command with* into `.venv/`. It does **not** download a new interpreter and
   cannot change the Python version — for that you need conda (or uv's Python management).
2. **It holds Python (PyPI) packages only.** No GDAL, no CUDA, no compilers. Those must
   already be on your system.

### The whole lifecycle

```bash
# 1) create it (conventionally named .venv, inside your project)
python -m venv .venv

# 2) activate it — now `python` and `pip` point INSIDE .venv
source .venv/bin/activate        # Linux / macOS
# .venv\Scripts\activate         # Windows PowerShell

# 3) install packages (into .venv only)
pip install -r python/3.12/lockfiles/requirements/04-web.txt

# 4) work… then leave it
deactivate

# 5) delete it anytime — it's just a folder
rm -rf .venv
```

**How to tell it's active:** your prompt shows `(.venv)`, and `which python` (or
`Get-Command python`) points inside `.venv/`. Add `.venv/` to `.gitignore` — you commit
the `requirements.txt`, never the environment.

---

## 4. conda environment vs. `venv` — the key comparison

Both are "virtual environments" (isolated package sets), but they are **not** the same:

| | **conda environment** | **`venv`** |
|---|---|---|
| Created by | `conda`/`mamba` | `python -m venv` (or `uv venv`) |
| Provides the Python interpreter? | **Yes** — can be any version | No — reuses the Python that made it |
| Installs native libraries (GDAL, CUDA…)? | **Yes** | No — PyPI wheels only |
| Package source | conda-forge (+ pip) | PyPI (pip/uv) |
| Where it lives | a central conda `envs/` dir | wherever you put it (usually `./.venv`) |
| Size / speed | larger, heavier solves | tiny, instant |
| Best for | scientific/dev, cross-platform native deps | pure-Python apps, production, CI/CD |

> **Don't nest them.** A conda environment is *already* isolated, so you rarely create a
> `venv` inside one. Pick **one** per project: conda **or** venv.

---

## 5. `venv` + uv — same idea, much faster

`uv` can create and fill a venv far faster than the built-ins, and it reads the very same
`requirements.txt`:

```bash
uv venv                                    # creates .venv (like python -m venv)
uv pip install -r python/3.12/lockfiles/requirements/04-web.txt   # fills it, fast
```

`uv venv` **is** a venv — identical concept, Rust-fast tooling. (uv can additionally
download Python interpreters with `uv python install`, edging into conda's territory, but
it still never manages native system libraries.)

---

## 6. When to use which — the decision guide

```text
Does your project need non-Python system libs (GDAL, CUDA, MKL, cmdstan, a compiler)?
│
├── YES ─────────────────────────────► conda / mamba
│                                       (environments/*.yml + lockfiles/<platform>/)
│
└── NO (pure-Python: web APIs, most services, tools)
        │
        ├── want the standard, zero-install baseline ──► python -m venv + pip
        │
        └── want speed & a built-in locker ────────────► uv venv + uv pip
                                                          (lockfiles/requirements/*.txt)
```

**Rule of thumb:** *Develop with conda. Ship with a venv + uv* — **if** the service's
dependencies are pure-PyPI. If production still needs GDAL/CUDA/etc., ship the conda
environment (or a conda-based image) instead.

---

## 7. "CD uses uv — right?" — yes, and here's why

In **Continuous Deployment** you repeatedly build an image and deploy it. What matters is
**speed, size, and exact reproducibility**:

- **Speed:** uv resolves and installs in **seconds** (often 10–100× faster than pip).
- **Reproducibility:** uv installs a **fully-pinned** `requirements.txt` (every package +
  version), so the image is the same every build.
- **Size:** a venv/system install of only the PyPI wheels you need is far smaller than a
  full conda environment (which carries system libraries and compilers).

A typical Dockerfile for a Python service — note it installs into the **container's system
Python** (`--system`), because the container itself is the isolation, so no venv is needed:

```dockerfile
FROM python:3.12-slim
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv
COPY python/3.12/lockfiles/requirements/04-web.txt requirements.txt
RUN uv pip install --system --no-cache -r requirements.txt
COPY . /app
CMD ["uvicorn", "app:app", "--host", "0.0.0.0"]
```

Locally you'd use a **venv** for the same install; in a container you can skip it with
`--system`. **CD uses uv because most services are pure Python** — not a universal law: a
GDAL/CUDA-heavy worker still ships as a conda-based image.

---

## 8. How this repo's two lock artifacts relate

```text
environments/04-web.yml          (INTENT, conda names, unpinned)
   │
   ├── conda-lock ─────────────►  lockfiles/linux-64/04-web.conda.lock   (DEV: exact,
   │                                                                       incl. native libs)
   └── (PyPI names) uv compile ─►  lockfiles/requirements/04-web.txt      (PROD: exact,
                                    │                                       PyPI wheels only)
                                    └── installed into a venv (or --system in a container)
```

They are **not** identical and cannot be — a conda env contains packages that don't exist
on PyPI (and vice-versa). Each targets a different stage.

---

## 9. Name gotcha: conda name ≠ PyPI name

The `requirements.txt` files use **PyPI** names; the conda YAMLs use **conda-forge** names.

| conda-forge | PyPI (in requirements.txt) | import |
|-------------|----------------------------|--------|
| `pytorch` | `torch` | `torch` |
| `opencv` | `opencv-python-headless` | `cv2` |
| `feature_engine` | `feature-engine` | `feature_engine` |
| `redis-py` | `redis` | `redis` |
| `docker-py` | `docker` | `docker` |
| `beautifulsoup4` | `beautifulsoup4` | `bs4` |

---

## 10. Caveats — where venv/pip/uv is *not* a drop-in

Some environments rely on conda's native-library superpowers and **don't translate cleanly
to a venv**:

- **`07-geospatial` (GDAL/rasterio/fiona):** the PyPI GDAL story needs system GDAL/GEOS/PROJ
  to build. Prefer the **conda** environment in production.
- **`08-timeseries` (Prophet):** compiles Stan via `cmdstan`, a native toolchain conda
  provides.
- **`06-tensorflow` / GPU:** GPU builds and CUDA come from conda or vendor wheels.

For these, prefer conda, or install the system libraries yourself before `pip install`.

---

## 11. Mastery checklist

You've mastered this when you can explain, in your own words:

- [ ] Why a **virtual environment** exists (isolate one project's packages from another's).
- [ ] What `venv` reuses (your existing Python) and what it **can't** do (change Python
      version; install native libs).
- [ ] The activate → install → deactivate → delete lifecycle.
- [ ] How a **conda environment** differs from a **venv** (interpreter + native libs vs.
      PyPI-only).
- [ ] That `uv venv` is just a faster `venv`, and `uv pip install` a faster `pip install`.
- [ ] Why **CD** installs a pinned `requirements.txt` with uv (speed, size, reproducibility)
      — into a venv locally or `--system` in a container.
- [ ] Which of this repo's envs **must** stay on conda (geospatial, prophet, GPU).

---

## 12. Quick commands

```bash
# ── venv (built-in) ─────────────────────────────────────────────
python -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r python/3.12/lockfiles/requirements/04-web.txt
deactivate

# ── venv + uv (fast) ────────────────────────────────────────────
uv venv
uv pip install -r python/3.12/lockfiles/requirements/04-web.txt

# ── conda / mamba (dev, native libs) ────────────────────────────
mamba env create -f python/3.12/environments/04-web.yml
conda activate py312-web

# ── regenerate a pinned requirements.txt from its intent ────────
uv pip compile python/3.12/lockfiles/requirements/04-web.in \
  -o python/3.12/lockfiles/requirements/04-web.txt --python-version 3.12 --python-platform linux
```

---

## 13. Glossary

- **virtual environment** — an isolated folder of Python packages for one project.
- **`venv`** — Python's built-in module for creating a virtual environment (PyPI-only,
  reuses your current Python).
- **activate / deactivate** — switch your shell into / out of an environment.
- **PyPI** — the Python Package Index; where pip/uv download from.
- **conda-forge** — the community conda channel this repo uses.
- **wheel** — a pre-built, ready-to-install Python package (no compiler needed).
- **resolver** — the component that picks a mutually-compatible set of versions.
- **pin / lock** — record exact versions so installs are reproducible.
- **`.in` vs `.txt`** — `requirements.in` is loose *intent*; `uv pip compile` turns it into
  a fully-pinned `requirements.txt`.
- **CD** — Continuous Deployment: automated build-and-ship pipelines.
