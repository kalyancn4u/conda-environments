# The uv manual

<sub>📍 [conda-environments](../README.md) › [docs](README.md) › **uv manual**</sub>

> **In one sentence:** *uv* is a very fast tool for making Python **virtual environments** and
> installing **PyPI packages** into them — a quicker replacement for `python -m venv` + `pip`.
> This manual explains **every uv command used in this repository**, from zero.

No prior knowledge assumed. Read sections 1–5 once; use the rest as a reference.
Its sibling is the [conda manual](conda-manual.md). To decide *which tool to use when*, read
[conda vs. uv](conda-vs-uv.md).

**Contents**
1. [The 5-minute mental model](#1-the-5-minute-mental-model)
2. [Install and check](#2-install-and-check)
3. [Your first environment](#3-your-first-environment)
4. [Virtual environments: `uv venv`](#4-virtual-environments-uv-venv)
5. [Installing packages: `uv pip install`](#5-installing-packages-uv-pip-install)
6. [Locking versions: `uv pip compile`](#6-locking-versions-uv-pip-compile)
7. [Exact sync: `uv pip sync`](#7-exact-sync-uv-pip-sync)
8. [Run a tool once: `uv tool run` / `uvx`](#8-run-a-tool-once-uv-tool-run--uvx)
9. [Installing Python itself](#9-installing-python-itself)
10. [Using uv safely next to conda](#10-using-uv-safely-next-to-conda)
11. [Where this repo uses uv](#11-where-this-repo-uses-uv)
12. [Troubleshooting](#12-troubleshooting)
13. [Cheat sheet](#13-cheat-sheet)
14. [Sources](#14-sources)

---

## 1. The 5-minute mental model

| Word | Plain meaning |
|------|---------------|
| **PyPI** | The Python Package Index — the public shop where `pip`/`uv` get Python packages. |
| **Virtual environment** ("venv") | A private folder (usually `.venv`) with its own Python packages, so projects don't interfere. |
| **Requirements file** | A text list of packages, one per line (`requirements.txt`). |
| **Resolve / compile** | Work out *exact* versions that fit together, from a loose wish-list. |
| **Lock** | The exact-versions result of resolving; installing it gives the same set every time. |

This repo keeps **two files per environment** in `python/<ver>/lockfiles/requirements/`:

```text
04-web.in   ── loose wish-list ("fastapi", "uvicorn")   ← you edit this
     │  uv pip compile                                   (resolve once)
     ▼
04-web.txt  ── every package pinned exactly              ← you install this
     │  uv pip install -r
     ▼
   .venv    ── the working environment
```

**uv vs pip:** same idea, same PyPI packages, far faster. **uv vs conda:** uv installs *only
Python packages from PyPI*; conda also installs native libraries (GDAL, CUDA…).
Use uv for slim, pure-Python services (production/CI); use conda for scientific stacks.

---

## 2. Install and check

**Linux / macOS**

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

**Windows (PowerShell)**

```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

**Any OS, via pip** (works, but the standalone installer above is the official first choice):

```bash
pip install uv
```

Then **open a new terminal** and check:

```bash
uv --version        # e.g. "uv 0.12.11"
```

Update later (only if you used the standalone installer; otherwise upgrade with the tool you
installed it with):

```bash
uv self update
```

Check your whole toolbox at once with the repo's health-check:
`./scripts/doctor.sh` (Linux/macOS) or `.\scripts\doctor.ps1` (Windows).

---

## 3. Your first environment

Run from the **repo root**. First, make sure **no conda environment is active**
(`conda deactivate`; see [§10](#10-using-uv-safely-next-to-conda)).

```bash
# 1. Create a private venv in ./.venv
uv venv

# 2. Enter it
source .venv/bin/activate            # Linux/macOS
.venv\Scripts\activate               # Windows PowerShell

# 3. Install a pinned set from this repo
uv pip install -r python/3.12/lockfiles/requirements/04-web.txt

# 4. Leave when done
deactivate
```

Shortcut — the repo script does steps 1 and 3 for you, and it is built so it can never install
into an active conda env:

```bash
./scripts/setup-venv.sh -p 3.12 04-web         # Linux/macOS
.\scripts\setup-venv.ps1 -p 3.12 04-web        # Windows
```

---

## 4. Virtual environments: `uv venv`

| Command | Result |
|---------|--------|
| `uv venv` | Creates `.venv` in the current folder. |
| `uv venv my-env` | Creates it at a path you choose (`my-env/`). |
| `uv venv --python 3.12` | Uses a specific Python (`-p` is short). uv will find it, or fetch one ([§9](#9-installing-python-itself)). |

**Activate / deactivate**

| Shell | Activate | Leave |
|-------|----------|-------|
| Linux / macOS (bash, zsh) | `source .venv/bin/activate` | `deactivate` |
| Windows PowerShell | `.venv\Scripts\activate` | `deactivate` |

You don't *have* to activate: `uv pip install --python .venv/bin/python …` (Windows:
`.venv\Scripts\python.exe`) targets the venv directly.

**Remove** a venv by deleting its folder (`rm -rf .venv` / `Remove-Item -Recurse .venv`).
Nothing else is affected.

---

## 5. Installing packages: `uv pip install`

The `uv pip …` commands mirror pip's, so pip knowledge transfers.

```bash
uv pip install -r requirements.txt          # from a requirements file (-r = --requirements)
```

Flags used in this repo:

| Flag | Meaning | When |
|------|---------|------|
| `-r FILE` | Install everything listed in `FILE`. | Always. |
| `--python PATH` | Install into the environment of *that* Python — explicit and safe. | Scripts; when you don't want to rely on what's activated. |
| `--system` | Install into the machine's **system** Python — no venv. | **Containers/CI only**; the container is the isolation. |
| `--no-cache` (`-n`) | Don't read/write uv's download cache. | Keeps Docker images small. |
| `--prefix DIR` | Install into `DIR` instead of a Python's own folder. | Multi-stage Docker builds (copy `DIR` to the final image). |

Examples from the repo:

```bash
uv pip install --python .venv/bin/python -r python/3.12/lockfiles/requirements/04-web.txt
uv pip install --system --no-cache -r requirements.txt     # container mode
```

> uv doesn't uninstall extras when you run `uv pip install`; for an **exact** match use
> [`uv pip sync`](#7-exact-sync-uv-pip-sync).

---

## 6. Locking versions: `uv pip compile`

Turns a loose `.in` wish-list into a fully pinned `.txt`. Nothing is installed.

```bash
uv pip compile 04-web.in -o 04-web.txt --python-version 3.12 --python-platform linux
```

| Flag | Meaning |
|------|---------|
| `FILE.in` | Input: top-level package names (one per line). |
| `-o FILE` / `--output-file` | Write the result here. **Without it, uv only prints to the screen.** |
| `--python-version X.Y` | Resolve *as if* running that Python. |
| `--python-platform P` | Resolve for that OS: `linux`, `windows`, `macos` (or precise targets like `x86_64-unknown-linux-gnu`, `aarch64-apple-darwin`). |
| `--universal` | Instead, make **one** file that works on all OSes. |
| `--no-annotate` | Omit the "# via …" comments (cleaner file). |
| `--no-header` | Omit the header comment (keeps the file identical across machines). |
| `--exclude-newer DATE` | Ignore packages published after `DATE` (e.g. `2026-06-01`) — "newest release that has had time to prove itself". |
| `--prerelease disallow` | Never pick alpha/beta/release-candidate versions. |
| `--system-certs` | Trust your computer's certificate store (fixes errors behind company proxies). |

### A lock is specific to a target

A resolution depends on Python version **and** operating system (different wheels exist per
OS). The `.txt` files committed here target **Python `<ver>` + Linux**. For other systems
recompile from the same `.in`:

```bash
uv pip compile 04-web.in -o 04-web-win.txt --python-version 3.12 --python-platform windows
uv pip compile 04-web.in -o 04-web-mac.txt --python-version 3.12 --python-platform macos
uv pip compile 04-web.in -o 04-web.txt     --python-version 3.12 --universal   # one file, all OSes
```

Why the repo pins for Linux: that's the production deploy target. More in
[conda vs. uv](conda-vs-uv.md#are-the-requirementstxt-os-specific-yes).

---

## 7. Exact sync: `uv pip sync`

```bash
uv pip sync requirements.txt
```

Like `install`, but **also removes** anything installed that isn't in the file — the
environment ends up *exactly* equal to the file.

> ⛔ **Never run `uv pip sync` against a conda environment.** It would delete every package
> that isn't in the requirements file. Use it only in a dedicated venv.

---

## 8. Run a tool once: `uv tool run` / `uvx`

Runs a command-line tool from PyPI in a **temporary, isolated** environment — nothing is
installed permanently.

```bash
uv tool run pip-audit -r requirements.txt     # long form
uvx pip-audit -r requirements.txt             # identical shortcut
```

The repo's `audit-env` script uses this to run **`pip-audit`** (a vulnerability scanner):

```bash
./scripts/audit-env.sh -p 3.12 04-web         # audit a pinned requirements file
./scripts/audit-env.sh --venv .venv           # audit a venv
```

---

## 9. Installing Python itself

uv can download Python interpreters too:

```bash
uv python install 3.12
```

Useful when the Python you need isn't on your machine. (For *scientific* stacks, conda
managing Python for you is still the simpler route.)

---

## 10. Using uv safely next to conda

uv treats an **active conda environment as a valid install target** (it honours
`CONDA_PREFIX`). If one is active and you run `uv pip install`, packages go **into the conda
env** — mixing pip into conda, the classic cause of ABI clashes.

Three habits keep them apart:

1. **`conda deactivate` before any uv work.**
2. **Use a venv**, and aim uv at it explicitly:
   ```bash
   uv venv .venv
   uv pip install --python .venv/bin/python -r requirements.txt
   ```
3. **Never `uv pip sync` a conda env** ([§7](#7-exact-sync-uv-pip-sync)).

`./scripts/doctor.sh` warns if a conda env is active while you're heading down the uv path;
`./scripts/setup-venv.sh` refuses to install into one. Full discussion:
[conda vs. uv §5](conda-vs-uv.md).

---

## 11. Where this repo uses uv

| Place | What it runs |
|-------|--------------|
| `scripts/setup-venv.sh` / `.ps1` | `uv venv <dir>` then `uv pip install --python <venv-python> -r <req>`; with `--system`: `uv pip install --system --no-cache -r <req>`. Falls back to `python -m pip` if uv is missing. |
| `scripts/audit-env.sh` / `.ps1` | `uvx` / `uv tool run pip-audit …` |
| `scripts/uv-to-conda.py` | `uv pip compile` to resolve *unpinned* packages before writing a conda `environment.yml` (flags below). See the [uv-to-conda guide](uv-to-conda.md). |
| `docker/Dockerfile.uv` | `uv pip install --python /usr/local/bin/python --prefix /install --no-cache -r <requirements>`; uv itself is copied from the official `ghcr.io/astral-sh/uv` image. |
| `python/<ver>/lockfiles/requirements/` | The `.txt` files were produced with `uv pip compile … --python-version <ver> --python-platform linux`. |

**What `uv-to-conda.py` passes to uv** — `uv pip compile <in> --python-version <X.Y>
--output-file <out> --no-annotate --no-header`, plus:

| Strategy / option | Extra flags |
|-------------------|-------------|
| `--strategy latest` (default) | none — newest versions. |
| `--strategy stable` | `--exclude-newer <today − N days> --prerelease disallow`. |
| `--system-certs` | `--system-certs` |

---

## 12. Troubleshooting

| Symptom | Likely cause → fix |
|---------|--------------------|
| `uv: command not found` | Not installed, or terminal not restarted → [§2](#2-install-and-check). |
| `invalid peer certificate: UnknownIssuer` | A company proxy intercepts HTTPS → add `--system-certs`. |
| uv offers to create a virtual environment | No venv found → `uv venv`, or use `--python`/`--system` deliberately. |
| Packages appeared in my conda env | uv ran while conda was active → [§10](#10-using-uv-safely-next-to-conda); repair with conda. |
| "No solution found" / no matching version | The requested Python/OS has no wheel yet (e.g. TensorFlow on 3.14) → use another Python version, or conda. |
| Lock works on Linux, fails on Windows | Locks are per-target → recompile for it ([§6](#a-lock-is-specific-to-a-target)). |
| A native library is missing | uv can't install non-Python libraries → use conda ([manual](conda-manual.md)). |

More: [troubleshooting](troubleshooting.md) · [FAQ](faq.md).

---

## 13. Cheat sheet

```bash
# install uv
curl -LsSf https://astral.sh/uv/install.sh | sh     # Windows: see §2
uv --version
uv self update

# environments
uv venv                                   # create .venv
source .venv/bin/activate                 # Windows: .venv\Scripts\activate
deactivate
uv python install 3.12                    # fetch a Python

# install
uv pip install -r requirements.txt
uv pip install --python .venv/bin/python -r requirements.txt
uv pip install --system --no-cache -r requirements.txt     # containers only
uv pip sync requirements.txt              # EXACT match (removes extras) — venvs only

# lock
uv pip compile X.in -o X.txt --python-version 3.12 --python-platform linux
uv pip compile X.in -o X.txt --python-version 3.12 --universal

# run once
uvx pip-audit -r X.txt                    # = uv tool run pip-audit -r X.txt
```

---

## 14. Sources

Checked against the official uv documentation **and the installed uv's own `--help`**
(uv 0.12.11):

- uv — [installation](https://docs.astral.sh/uv/getting-started/installation/) ·
  [CLI reference](https://docs.astral.sh/uv/reference/cli/) ·
  [pip interface: environments](https://docs.astral.sh/uv/pip/environments/) ·
  [pip interface: compile & sync](https://docs.astral.sh/uv/pip/compile/)
- Project home — [astral-sh/uv](https://github.com/astral-sh/uv)
- `pip-audit` — [pypa/pip-audit](https://github.com/pypa/pip-audit)

Previous: the [conda manual](conda-manual.md).
