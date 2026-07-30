# Workflows — from a fresh machine to CI/CD, security, and MLOps

<sub>📍 [conda-environments](../README.md) › [docs](README.md) › **workflows**</sub>

This is the **hands-on companion** to the rest of the docs. Where
[architecture](architecture.md) explains *why* the repo is split into modular
environments and [conda-vs-uv](conda-vs-uv.md) explains the *tools*, this page is a
**cookbook**: concrete, copy-pasteable workflows for the situations a real project
runs into — local development, notebooks, production services, throwaway
automation, containers, testing/QA, **security testing**, CI/CD, and MLOps.

Written **complete-novice → mastery**. No prior knowledge assumed; if a term is new,
the [glossary in conda-vs-uv.md](conda-vs-uv.md#13-glossary) defines it. Read sections
1–4 in order, jump to whichever [scenario (§5)](#5-workflows-by-scenario) you're in,
then run a full [walkthrough (§6)](#6-two-complete-walkthroughs-from-nothing-to-a-result)
to see the pieces combine. Commands come in **Linux/macOS** and **Windows PowerShell**
forms, and most show the **output you should expect**.

> **New scripts referenced here** live in `python/<ver>/scripts/` alongside the
> original helpers. Everything works on **Linux/macOS (`.sh`)** and **Windows
> PowerShell (`.ps1`)**, and adapts automatically to whichever Python version tree
> it lives in (`3.10`, `3.12`, …).

---

## 1. The mental model: two install worlds, one repo

Every workflow below is a combination of **a tool** and **a stage**. There are only
**two install worlds**, and the whole repo (and your career) gets simpler once you
internalize the split:

| | **conda world** | **PyPI world** |
|---|---|---|
| Managers | `conda` · `mamba` · `micromamba` | `venv` + `pip` · **`uv`** |
| Installs | Python **+ native libraries** (GDAL, CUDA, MKL, cmdstan) | **Python packages only** (from PyPI) |
| This repo's source of truth | `environments/*.yml` → `lockfiles/<platform>/*.conda.lock` | `lockfiles/requirements/*.in` → `*.txt` |
| Best at | **development**, science, anything with native deps | **production/CD**, slim pure-Python services |
| Rule of thumb | **develop here** | **ship here** (when deps are pure-Python) |

The single most important safety rule connecting the two worlds: **never let
`uv`/`pip` run while a conda environment is active** — it will install *into* the
conda env and corrupt it. (`doctor` warns you; `setup-venv` refuses.) Full
explanation: [conda-vs-uv §5](conda-vs-uv.md#5-venv--uv--same-idea-much-faster).

---

## 2. The toolbox at a glance

All helpers live in `python/<ver>/scripts/`. Run the `.sh` on Linux/macOS, the
`.ps1` on Windows.

| Script | World | What it does | Scenario |
|--------|-------|--------------|----------|
| **`doctor`** | both | Preflight: what's installed, channel config, shell safety | §3, first run |
| `create-env` | conda | Create a modular env from a `.yml` | §5A |
| `update-env` | conda | Update an env to match its `.yml` (prunes) | §5A |
| `verify-env.py` | conda | Smoke-test that an env's headline packages import | §5G |
| `compare-envs` | conda | Diff two envs / list outdated packages | §5G |
| `export-env` | conda | Snapshot an env (frozen/nobuild/explicit) | §5J, §7 |
| `clean-env` | conda | Reclaim disk from conda caches | maintenance |
| **`register-kernel`** | conda | Expose an env as a Jupyter kernel | §5C |
| **`micromamba-env`** | conda | **Zero-install** create + verify | §5E |
| **`setup-venv`** | PyPI | Create a venv + install a pinned `requirements.txt` | §5D |
| **`audit-env`** | both | **Security**: CVE scan + conda/pip clash check | §5H |
| `test-env` | conda | Build + verify in the CI container (Docker) | §5G, §5I |

**Containers** live at the repo root under [`docker/`](../docker/): `Dockerfile.uv`
(slim PyPI service) and `Dockerfile.conda` (scientific/native image). See §5F.

> Bold = added to make the full matrix (venv/conda/mamba/micromamba/uv ·
> monolith/modular · dockerized · dev/test/qa/security/CI-CD/MLOps) practicable
> end-to-end.

---

## 3. Your first ten minutes (any machine)

**Step 0 — get a tool if you have none.** You need *one* environment manager. If a
later `doctor` run says everything is missing, install one of these first (each is a
one-time, per-machine setup):

```bash
# Miniforge = conda + mamba, pre-pointed at conda-forge (the recommended dev tool).
# Linux/macOS — download & run the installer for your OS/arch:
curl -L -O "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh"
bash Miniforge3-$(uname)-$(uname -m).sh        # then restart your shell
# Windows: download & run the Miniforge3 .exe from that same releases page.

# uv = the fast venv/PyPI tool (only needed for the production/venv path, §5D):
curl -LsSf https://astral.sh/uv/install.sh | sh      # Windows: see https://docs.astral.sh/uv/
```

> Don't want to install anything at all? The **[micromamba path (§5E)](#5e-zero-install--throwaway--automation-micromamba-env)**
> downloads a single ~30 MB binary on demand and needs nothing pre-installed.

**Step 1 — see what you have.** This changes nothing:

```bash
cd conda-environments
./python/3.12/scripts/doctor.sh            # Windows: .\python\3.12\scripts\doctor.ps1
```

A healthy machine prints something like (yours will differ):

```text
conda-environments doctor — context: python/3.12 (py312-*)
===========================================================

Solvers & installers
  OK   conda        conda 24.x.x
  OK   mamba        mamba 1.x.x
  !!   uv           (not found — needed for the venv/production path)
  ...
conda channel configuration
  OK   conda-forge is in your channel list
  !!   channel_priority is not strict — run: conda config --set channel_priority strict
...
Ready for the conda/mamba path. Next: ./scripts/create-env.sh 01-core
```

`OK` = present/good, `!!` = a hint to act on. Two lines above tell you exactly what to
run next.

**Step 2 — one-time conda channel setup** (only if `doctor` flagged it):

```bash
conda config --add channels conda-forge
conda config --set channel_priority strict
```

**Step 3 — create, activate, and verify the daily-driver environment:**

```bash
./python/3.12/scripts/create-env.sh 01-core     # solves + installs py312-core (a few minutes)
conda activate py312-core                        # your prompt now shows (py312-core)
python python/3.12/scripts/verify-env.py --env core
```

`verify-env` prints one line per package and a final verdict — this is what a **pass**
looks like:

```text
OK  python 3.12.x (as expected)
------------------------------------------------------------
[core]
OK  numpy       2.x.x
OK  pandas      2.x.x
...
------------------------------------------------------------
SUCCESS: all imports succeeded.
```

If instead you see `!! ... IMPORT FAILED` and `FAILED: N import(s) did not succeed`,
the environment didn't build cleanly — see [troubleshooting.md](troubleshooting.md).

> **First `conda activate` errors with "conda not initialized"?** Run `conda init`
> (bash/zsh/powershell), open a new shell, and try again — a one-time step.

---

## 4. Which workflow am I in?

```text
Do you need native/system libraries (GDAL, CUDA, MKL, cmdstan/Prophet, OpenCV)?
│
├── YES ───────────────────────► conda world
│      │
│      ├── daily dev on your machine ............ §5A  create-env (mamba)
│      ├── one env for exploration (monolith) ... §5B  layering + lock
│      ├── notebooks across many envs ........... §5C  register-kernel
│      ├── CI / throwaway / no install .......... §5E  micromamba-env
│      └── ship a scientific image .............. §5F  Dockerfile.conda
│
└── NO (pure-Python: web APIs, most services, tools)
       │
       ├── local/prod install ................... §5D  setup-venv (uv)
       └── ship a slim service image ............ §5F  Dockerfile.uv

Cross-cutting, every project:  test/QA §8 · security §5H · CI/CD §5I · MLOps §5J
```

---

## 5. Workflows by scenario

### 5A. Local development on modular environments (conda/mamba)

The default. Create the small environment for the concern you're working on; keep
them separate. `create-env`/`update-env` auto-prefer `mamba` when present.

```bash
# create the environments you need, one per concern
./python/3.12/scripts/create-env.sh 01-core      # everyday data work
./python/3.12/scripts/create-env.sh 02-ml        # gradient boosting, tuning, tracking
./python/3.12/scripts/create-env.sh 05-tools     # pytest/ruff/mypy/playwright

conda activate py312-ml
# …work…

# After editing 02-ml.yml, bring the env back in line with its definition:
./python/3.12/scripts/update-env.sh 02-ml        # note: this PRUNES removed packages
```

```powershell
# Windows PowerShell equivalents
.\python\3.12\scripts\create-env.ps1 01-core
.\python\3.12\scripts\update-env.ps1 02-ml
```

Why separate envs? A broken `numpy` upgrade in `ml` can't take down `web`. See
[architecture.md](architecture.md).

### 5B. One "monolith" all-in-one environment

Sometimes you want a single env to activate (open-ended exploration, one Jupyter
kernel that does everything). Use a ready-made kitchen-sink template, then **lock it
immediately** because merged envs are fragile:

```bash
# pick ONE deep-learning framework — TF and PyTorch don't reliably coexist
./python/3.12/scripts/create-env.sh ../templates/all-in-one-pytorch.yml
conda activate py312-all-pytorch
python python/3.12/scripts/verify-env.py --env allinone-pytorch

# capture the exact working set the moment it solves (snapshot):
./python/3.12/scripts/export-env.sh py312-all-pytorch
```

The full trade-offs, the manual layering recipe (`conda env update` without
`--prune`), and why to keep TensorFlow out are in the
[root README](../README.md#building-one-all-in-one-environment-iterative-layering).

### 5C. Notebooks across many modular environments (register-kernel)

You don't need a monolith to use many stacks in JupyterLab — register each modular
env as a **kernel**, then pick it per-notebook:

```bash
# launch Lab from an env that has jupyterlab (01-core)
conda activate py312-core

# expose the ML and DL envs as kernels (installs ipykernel if missing)
./python/3.12/scripts/register-kernel.sh py312-ml  "ML (py3.12)"
./python/3.12/scripts/register-kernel.sh py312-dl  "Deep Learning (py3.12)"
./python/3.12/scripts/register-kernel.sh --list

jupyter lab        # New Notebook → choose the kernel you want
```

```powershell
.\python\3.12\scripts\register-kernel.ps1 py312-ml "ML (py3.12)"
.\python\3.12\scripts\register-kernel.ps1 -Remove py312-ml   # unregister
```

This gives the *convenience* of one Jupyter with the *hygiene* of modular envs.

### 5D. Production / pure-Python services (setup-venv + uv)

When a service's dependencies are pure-PyPI, ship a slim **venv** built from the
repo's pinned `requirements.txt`. `setup-venv` prefers `uv` (fast) and falls back to
`python -m venv` + `pip`. It always targets the venv's own interpreter, so it can
never clobber a conda env.

The full lifecycle — **build → activate → run → leave**:

```bash
# 1) build ./.venv from lockfiles/requirements/04-web.txt (uv makes this take seconds)
./python/3.12/scripts/setup-venv.sh 04-web
```

The script ends by telling you exactly how to activate it:

```text
>> Requirements: .../lockfiles/requirements/04-web.txt
>> Creating venv with uv at: .venv
>> Installing into: .venv/bin/python
>> Done. Activate with:
     source .venv/bin/activate
```

```bash
# 2) activate — now `python`/`pip` point INSIDE .venv (prompt shows (.venv))
source .venv/bin/activate                 # Windows: .venv\Scripts\Activate.ps1

# 3) run your actual service (04-web ships fastapi + uvicorn)
python -c "import fastapi, uvicorn; print('web stack ready')"
# uvicorn app:app --host 0.0.0.0 --port 8000     # <- your real app

# 4) when done, leave the venv (it's just a folder; delete anytime with: rm -rf .venv)
deactivate
```

```powershell
# Windows PowerShell
.\python\3.12\scripts\setup-venv.ps1 04-web
.\.venv\Scripts\Activate.ps1
python -c "import fastapi, uvicorn; print('web stack ready')"
deactivate
```

Other forms — a custom venv directory, an explicit requirements file, or **container
mode** (install straight into the container's system Python, no venv):

```bash
./python/3.12/scripts/setup-venv.sh 04-web .venv-web        # custom venv dir
./python/3.12/scripts/setup-venv.sh path/to/requirements.txt
./python/3.12/scripts/setup-venv.sh 04-web --system         # container/CI: no venv
```

> **Caveat:** a few environments need conda's native libraries and don't translate
> cleanly to a venv — `07-geospatial` (GDAL), `08-timeseries` (Prophet/cmdstan),
> `06-tensorflow`/GPU. Ship those with conda instead. See
> [conda-vs-uv §10](conda-vs-uv.md#10-caveats--where-venvpipuv-is-not-a-drop-in).

### 5E. Zero-install / throwaway / automation (micromamba-env)

For CI, a colleague's laptop with nothing installed, or a quick "does this solve?"
check — `micromamba-env` needs **no prior conda install**. If `micromamba` isn't on
`PATH`, it downloads the small static binary into a local, gitignored folder and
uses it in place. Nothing is installed system-wide.

```bash
# create py312-core and verify it, from a clean machine
./python/3.12/scripts/micromamba-env.sh 01-core

# from an explicit template path (no auto-verify):
./python/3.12/scripts/micromamba-env.sh ../templates/llm.yml

# custom root prefix (where envs are stored); delete the tree to clean up
MAMBA_ROOT_PREFIX=./mm ./python/3.12/scripts/micromamba-env.sh 01-core
```

```powershell
.\python\3.12\scripts\micromamba-env.ps1 01-core
```

The script creates the env **and** runs `verify-env` for you, ending with:

```text
>> Creating env 'py312-core' from .../environments/01-core.yml
...
>> Verifying imports (--env core)
...
SUCCESS: all imports succeeded.
>> Done. Run tools with:  micromamba run --name py312-core <command>
```

There's no `conda activate` with micromamba — run things through `micromamba run`:

```bash
micromamba run --name py312-core python -c "import pandas; print(pandas.__version__)"
micromamba run --name py312-core jupyter lab       # or any command the env provides
```

### 5F. Containers (Docker)

Two reference Dockerfiles under [`docker/`](../docker/), one per install world.
**Build from the repo root** (the build context must see `python/<ver>/`):

**Build → run → verify** the slim PyPI service image:

```bash
# build (from the repo root)
docker build -f docker/Dockerfile.uv \
  --build-arg PYVER=3.12 --build-arg REQUIREMENTS=04-web \
  -t conda-environments/web:uv .

# verify the stack is importable inside the image
docker run --rm conda-environments/web:uv \
  python -c "import fastapi, uvicorn; print('ok')"        # -> ok

# run your service (override the default CMD; publish the port)
docker run --rm -p 8000:8000 conda-environments/web:uv \
  uvicorn app:app --host 0.0.0.0 --port 8000
```

And the reproducible scientific image (native libs, via micromamba):

```bash
docker build -f docker/Dockerfile.conda \
  --build-arg KIND=environments --build-arg ENVFILE=07-geospatial \
  -t conda-environments/geo:conda .

docker run --rm conda-environments/geo:conda \
  python -c "import geopandas; print(geopandas.__version__)"
```

Full build-arg reference, the non-root/runtime split, and the "which image" guidance
are in [`docker/README.md`](../docker/README.md).

### 5G. Testing & QA

Two levels:

```bash
# 1) fast smoke test — do the headline packages import?  (CI-friendly exit code)
python python/3.12/scripts/verify-env.py --env core
python python/3.12/scripts/verify-env.py --all

# 2) full reproduction of the CI job — build + verify in the Miniforge container
./python/3.12/scripts/test-env.sh 01-core      # one env (needs Docker)
./python/3.12/scripts/test-env.sh --all        # every env
```

`test-env` runs the **exact** steps of the `test-environments` GitHub workflow, so a
green run locally means a green run in CI. Add your project's own `pytest` inside the
`05-tools` env for functional tests.

### 5H. Security testing (audit-env)

`audit-env` runs two independent, CI-friendly checks (non-zero exit on findings):

1. **Vulnerability scan** — `pip-audit` against the resolved package set (known CVEs
   from the PyPI Advisory DB / OSV). It's run *without* installing anything into your
   target, via `uvx` → `pipx run` → a local `pip-audit`.
2. **Hygiene** — for a conda env, the conda/pip **clash** check (the same one CI
   enforces): the ABI risk of the same package installed from both sources.

```bash
# audit a pinned requirements set (the reliable, static path — great in CI)
./python/3.12/scripts/audit-env.sh 04-web
./python/3.12/scripts/audit-env.sh --requirements python/3.12/lockfiles/requirements/04-web.txt

# audit a live environment
./python/3.12/scripts/audit-env.sh --name py312-web      # conda env (also runs clash check)
./python/3.12/scripts/audit-env.sh --venv .venv          # a venv
./python/3.12/scripts/audit-env.sh --name py312-web --json > audit.json
```

```powershell
.\python\3.12\scripts\audit-env.ps1 04-web
.\python\3.12\scripts\audit-env.ps1 -Name py312-web
```

A **clean** run ends like this (exit code `0` — CI stays green):

```text
== Vulnerability scan (pip-audit) ==========================
No known vulnerabilities found
== Hygiene: conda/pip package clashes ======================
no conda/pip clashes
===========================================================
PASS: no vulnerabilities or clashes detected.
```

A run **with a finding** names the package, the advisory, and the fixed version, and
exits non-zero so a CI gate fails:

```text
== Vulnerability scan (pip-audit) ==========================
Found 1 known vulnerability in 1 package
Name  Version ID             Fix Versions
----- ------- -------------- ------------
jinja2 3.1.3  GHSA-h5c8-rqwp 3.1.4
===========================================================
FINDINGS: review the report above.
```

To fix a finding: bump the pin in the relevant `requirements/*.in` and recompile
(`uv pip compile …`, see [§5D](#5d-production--pure-python-services-setup-venv--uv) and
the [requirements README](../python/3.12/lockfiles/requirements/README.md)), or update
the package in the conda env, then re-run `audit-env`.

> **Coverage note:** `pip-audit` reads PyPI (dist-info) metadata. Most conda-installed
> packages expose it and are covered; a few conda-only native packages may not appear.
> For those stacks, the conda lockfile (exact URLs + hashes) plus the clash check are
> your primary integrity controls.

### 5I. CI/CD — putting it together

The repo already ships three GitHub Actions workflows (`validate`,
`test-environments`, `update-lockfiles`). Here is a **complete, copy-pasteable** job
that chains the local helpers into a build → verify → security gate — drop it in
`.github/workflows/ci.yml`:

```yaml
name: ci
on: [push, pull_request]

jobs:
  build-and-audit:
    runs-on: ubuntu-latest
    # Run inside the same conda-forge image the repo's other workflows use:
    # it ships mamba/micromamba, so no toolchain install step is needed.
    container: condaforge/miniforge3:latest
    steps:
      - uses: actions/checkout@v4

      - name: Preflight (fail fast if the toolchain is missing)
        run: bash python/3.12/scripts/doctor.sh --strict

      - name: Build + verify the web environment (zero-install)
        run: bash python/3.12/scripts/micromamba-env.sh 04-web

      - name: Security gate — CVE scan of the pinned requirements
        run: bash python/3.12/scripts/audit-env.sh 04-web
```

Each step exits non-zero on failure, so a vulnerable dependency or a broken solve
**fails the check** and blocks the merge. Swap `04-web` for the environment your
project actually uses; add a `pytest` step (inside a `05-tools` env) for functional
tests.

> **Other CI systems** (GitLab CI, Jenkins, CircleCI) work the same way: run the same
> `bash python/3.12/scripts/*.sh` commands inside a `condaforge/miniforge3` container
> (or any image where you first run the micromamba path).

For **deployment**, build the container in [§5F](#5f-containers-docker) from the pinned
artifacts. The full intent→lock→ship model:

- **intent** — `environments/*.yml` and `requirements/*.in` (loosely pinned, OS-agnostic)
- **lock** — `lockfiles/<platform>/*.conda.lock` and `requirements/*.txt` (exact, per-target)
- **ship** — install from a lock in a container (`Dockerfile.conda`/`Dockerfile.uv`)

See [conda-vs-uv §8](conda-vs-uv.md#8-how-this-repos-two-lock-artifacts-relate) and the
[lockfiles guide](../python/3.12/lockfiles/README.md).

### 5J. MLOps

MLOps spans several of the above:

```bash
# 1) tracking/orchestration/ops SDKs in a dedicated env (kept out of the core modules)
./python/3.12/scripts/create-env.sh ../templates/mlops.yml   # mlflow, wandb, airflow, dvc, …

# 2) make experiments reproducible: snapshot or lock the training env
./python/3.12/scripts/export-env.sh py312-ml
#    …or generate a conda lockfile (Actions → update-lockfiles), then rebuild exactly.

# 3) notebooks against the ML/DL envs
./python/3.12/scripts/register-kernel.sh py312-dl "Deep Learning (py3.12)"

# 4) gate models' dependency supply chain
./python/3.12/scripts/audit-env.sh --name py312-mlops
```

Airflow is POSIX-only — run it under WSL2/Docker on Windows (noted in the template).

---

## 6. Two complete walkthroughs (from nothing to a result)

The sections above are à-la-carte. These two narratives chain them end-to-end so you
can see a *whole* task, in order. Run them verbatim.

### Walkthrough A — a data scientist: two stacks in one JupyterLab

Goal: analyse data in a notebook, and in the *same* Lab switch to a notebook that
trains a gradient-boosted model — without one giant environment.

```bash
# 1) confirm the toolchain (install Miniforge first if doctor says so — see §3, step 0)
./python/3.12/scripts/doctor.sh

# 2) build the two modular environments you need
./python/3.12/scripts/create-env.sh 01-core     # data work + JupyterLab
./python/3.12/scripts/create-env.sh 02-ml       # xgboost / lightgbm / optuna

# 3) expose the ML env as a Jupyter kernel (core already has one)
conda activate py312-core
./python/3.12/scripts/register-kernel.sh py312-ml "ML (py3.12)"
./python/3.12/scripts/register-kernel.sh --list        # confirm it's registered

# 4) launch Lab from core; create notebooks and pick the kernel per notebook
jupyter lab
#    Notebook 1 → kernel "Python (py312-core)"  → import pandas, explore
#    Notebook 2 → kernel "ML (py3.12)"          → import xgboost, train

# 5) reproducibility: snapshot whichever env produced a result you care about
./python/3.12/scripts/export-env.sh py312-ml
```

You now have the *convenience* of one Lab and the *hygiene* of small, independent
environments (a broken install in `ml` can't touch `core`).

### Walkthrough B — an engineer: a containerized, security-gated web service

Goal: take the `04-web` stack from nothing to a Docker image that runs FastAPI and
has passed a vulnerability scan.

```bash
# 1) develop locally in a fast, isolated venv (pure-Python service → PyPI world)
./python/3.12/scripts/setup-venv.sh 04-web
source .venv/bin/activate                       # Windows: .venv\Scripts\Activate.ps1
python -c "import fastapi, uvicorn; print('web stack ready')"
deactivate

# 2) security gate BEFORE you ship — scan the exact pinned requirements
./python/3.12/scripts/audit-env.sh 04-web       # must end in "PASS" / exit 0

# 3) build the slim production image (installs the same pinned requirements)
docker build -f docker/Dockerfile.uv \
  --build-arg REQUIREMENTS=04-web -t myservice:latest .

# 4) verify the image, then run it
docker run --rm myservice:latest python -c "import fastapi; print('ok')"
docker run --rm -p 8000:8000 myservice:latest \
  uvicorn app:app --host 0.0.0.0 --port 8000
```

Wire steps 2–3 into CI with the workflow in [§5I](#5i-cicd--putting-it-together) and the
same gate runs on every push. This is the full **develop → audit → ship** loop.

---

## 7. The reproducibility ladder

From least to most reproducible — pick the rung the situation needs:

| Rung | Artifact | Reproducibility | How |
|------|----------|-----------------|-----|
| 1 | `environments/*.yml` | intent; re-solves over time | `create-env` |
| 2 | `export-env` snapshots | this machine, this moment | `export-env` |
| 3 | `lockfiles/<platform>/*.conda.lock` | **exact**, per-OS, incl. native libs | Actions/`test-env` |
| 4 | `lockfiles/requirements/*.txt` | **exact**, per-OS, PyPI wheels only | `setup-venv` / `uv` |

Rules 3–4 are what you deploy. See [lockfiles — explained](../python/3.12/lockfiles/LOCKFILES-EXPLAINED.md).

---

## 8. Golden rules & common pitfalls

- **One world per shell.** Don't run `uv`/`pip` with a conda env active. `conda
  deactivate` first, or let `setup-venv` target a venv explicitly. (`doctor` checks
  this.)
- **`update-env` prunes.** It removes anything not in the `.yml`. That's intended for
  a single env — **never** use it to layer a monolith (§5B); use `conda env update`
  without `--prune`.
- **conda name ≠ PyPI name ≠ import name.** `pytorch`/`torch`/`torch`,
  `opencv`/`opencv-python-headless`/`cv2`. The `.yml` uses conda names, the
  `requirements.txt` uses PyPI names. See [package-selection.md](package-selection.md).
- **Locks are per-target.** A `linux-64` conda lock or a linux `requirements.txt`
  won't install correctly on Windows/macOS. Recompile/relock for the target.
- **TensorFlow + PyTorch rarely coexist.** Keep TF in its own `06-tensorflow` env.
- **Lock a monolith the moment it solves** — merged envs drift.

More: [troubleshooting.md](troubleshooting.md) · [faq.md](faq.md).

---

## 9. Script reference (new helpers)

Exit codes are **0 = success, non-zero = failure**, so all of these drop into CI.

### `doctor` — toolchain preflight (read-only)
```
doctor.sh [--strict]                 doctor.ps1 [-Strict]
```
Reports installed tools, conda channel config, and shell safety. `--strict` fails
when there is neither a conda-family solver nor `uv`. Changes nothing.

### `setup-venv` — venv + pinned requirements (PyPI world)
```
setup-venv.sh <req-name|path> [venv-dir|--system]
setup-venv.ps1 <Requirements> [VenvDir] [-System]
```
`<req-name>` resolves to `lockfiles/requirements/<name>.txt`. Prefers `uv`, falls
back to `venv`+`pip`. `--system`/`-System` installs into the current interpreter
(container mode) and refuses to run inside an active named conda env.

### `audit-env` — security & hygiene (both worlds)
```
audit-env.sh  (--name <env> | --venv <dir> | --requirements <file> | <req-name>) [--no-vulns] [--json]
audit-env.ps1 (-Name <env> | -Venv <dir> | -Requirements <file> | <req-name>) [-NoVulns] [-Json]
```
Runs `pip-audit` (CVEs) and, for conda targets, the conda/pip clash check. Exits
non-zero on any finding.

### `micromamba-env` — zero-install create + verify (conda world)
```
micromamba-env.sh  <env-stem|path-to-yml>
micromamba-env.ps1 <Env>
```
Downloads micromamba if absent (local, gitignored), creates the env named in the
`.yml`, and runs `verify-env.py` for the numbered environments. Honors
`MAMBA_ROOT_PREFIX`.

### `register-kernel` — env → Jupyter kernel (conda world)
```
register-kernel.sh  <env-name> [display-name] | --remove <env> | --list
register-kernel.ps1 <Env> [DisplayName]       | -Remove <env> | -List
```
Registers a conda env as a user-scope Jupyter kernel (installing `ipykernel` if
missing), so one JupyterLab can drive every modular env.

---

## 10. Mastery checklist

You've mastered the workflows when you can, without looking:

- [ ] Run `doctor` and read off exactly what to install/configure next.
- [ ] Explain the **two install worlds** and place any tool in the right one.
- [ ] Choose modular envs (§5A) vs. a monolith (§5B) and justify it.
- [ ] Build a production venv with `setup-venv` and know why it can't hurt a conda env.
- [ ] Bring up an environment on a machine with **nothing installed** (§5E).
- [ ] Register modular envs as Jupyter kernels and switch between them (§5C).
- [ ] Build both container images and say which service belongs in which (§5F).
- [ ] Run the security gate (`audit-env`) against a requirements file **and** a live
      env, and explain the coverage caveat for conda-native packages.
- [ ] Reproduce the CI environment tests locally (`test-env`) before pushing.
- [ ] Point to the right rung of the **reproducibility ladder** for a given need.
- [ ] Run [walkthrough A and B (§6)](#6-two-complete-walkthroughs-from-nothing-to-a-result)
      end-to-end and recognise the expected output at each step.

---

**See also:** [conda-vs-uv](conda-vs-uv.md) (the tools) ·
[architecture](architecture.md) (the design) ·
[lockfiles](../python/3.12/lockfiles/README.md) (reproducibility) ·
[docker/](../docker/) (images) · [troubleshooting](troubleshooting.md) · [faq](faq.md).
