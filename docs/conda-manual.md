# The conda manual

<sub>📍 [conda-environments](../README.md) › [docs](README.md) › **conda manual**</sub>

> **In one sentence:** *conda* builds an **isolated folder of software** (Python **and** the
> non-Python libraries it needs) for each project, so one project's packages can never break
> another's. This manual explains **every conda, mamba, micromamba and conda-lock command
> used in this repository**, from zero.

No prior knowledge assumed. Read sections 1–5 once; use the rest as a reference.
Its sibling is the [uv manual](uv-manual.md) (the PyPI / `venv` side). To decide *which*
to use when, read [conda vs. uv](conda-vs-uv.md).

**Contents**
1. [The 5-minute mental model](#1-the-5-minute-mental-model)
2. [Install and check](#2-install-and-check)
3. [One-time setup (channels)](#3-one-time-setup-channels)
4. [Your first environment](#4-your-first-environment)
5. [The daily cycle](#5-the-daily-cycle)
6. [Environment files (`.yml`)](#6-environment-files-yml)
7. [Reproducible rebuilds (lockfiles)](#7-reproducible-rebuilds-lockfiles)
8. [Housekeeping](#8-housekeeping)
9. [mamba and micromamba](#9-mamba-and-micromamba)
10. [conda-lock](#10-conda-lock)
11. [Jupyter kernels](#11-jupyter-kernels)
12. [Which repo script runs which command](#12-which-repo-script-runs-which-command)
13. [Troubleshooting](#13-troubleshooting)
14. [Cheat sheet](#14-cheat-sheet)
15. [Sources](#15-sources)

---

## 1. The 5-minute mental model

| Word | Plain meaning |
|------|---------------|
| **Package** | A ready-made piece of software (e.g. `numpy`). |
| **Environment** ("env") | A private folder holding one Python plus a chosen set of packages. Delete the folder and it's gone; nothing else is touched. |
| **Channel** | A website that hosts packages. This repo uses **`conda-forge`** only. |
| **Solver** | The part that works out *which versions fit together*. "Solving" is the pause you see after you press Enter. |
| **Activate** | "Step inside" an environment so `python` and friends come from it. |
| **`environment.yml`** | A text recipe describing an environment (its name, channels, packages). This repo's recipes are in `python/<ver>/environments/`. |
| **Lockfile** | A frozen, exact shopping list (URLs + hashes) that rebuilds an environment identically. See [§7](#7-reproducible-rebuilds-lockfiles). |

```text
recipe (.yml)  ──solve──►  environment (a folder)  ──activate──►  you use it
   intent                     exact versions chosen                 python, jupyter…
```

**Golden rules:** one environment per purpose · never install into `base` · always name what
you're targeting with `-n <env>`.

---

## 2. Install and check

Install a conda distribution once. [Miniforge](https://github.com/conda-forge/miniforge) is
the conda-forge-first installer (the same one this repo's CI uses); Miniconda also works.
Then **open a new terminal** and check:

```bash
conda --version        # prints e.g. "conda 26.1.1"
conda info             # prints details: version, paths, channels, active env
```

> **`conda: command not found`?** Run `conda init` once (or `conda init powershell` /
> `conda init bash` to name the shell), then **restart the terminal**. `conda init` edits
> your shell's startup file so that `conda activate` works.

Not sure your machine is ready? Run the repo's checker (details in [§12](#12-which-repo-script-runs-which-command)):

```bash
./scripts/doctor.sh          # Linux/macOS
.\scripts\doctor.ps1         # Windows PowerShell
```

---

## 3. One-time setup (channels)

Make conda-forge your default source and make its priority **strict**, so packages don't get
mixed from different sources (the top cause of "broken" environments):

```bash
conda config --add channels conda-forge        # add conda-forge to the channel list
conda config --set channel_priority strict     # only use lower channels if a package is absent above
```

Check what you have:

```bash
conda config --show channels                   # expect conda-forge to be listed first
conda config --show channel_priority           # expect: strict
```

| Flag | Meaning |
|------|---------|
| `--add KEY VALUE` | Add `VALUE` to a list setting (here: a channel). |
| `--set KEY VALUE` | Set a single-value setting. |
| `--show [KEY]` | Print current settings (all, or just `KEY`). |

---

## 4. Your first environment

Run everything **from the repo root**.

```bash
# 1. Create it from a recipe (downloads + installs; can take a few minutes)
conda env create --file python/3.12/environments/01-core.yml

# 2. Step inside
conda activate py312-core

# 3. Prove it works (repo helper: checks the key imports)
python scripts/verify-env.py -p 3.12 --env core

# 4. Step back out when done
conda deactivate
```

The name `py312-core` comes from the `name:` line inside the `.yml` file. Your prompt shows
`(py312-core)` while you're inside.

---

## 5. The daily cycle

### Create · list · remove

| Task | Command | Notes |
|------|---------|-------|
| Create an empty-ish env | `conda create --name myenv python=3.12` | `-n` is short for `--name`. |
| Create from a recipe | `conda env create --file <file>.yml` | Short: `-f`. Add `--yes` to skip the "Proceed?" question. |
| Preview without doing it | `conda env create --file <file>.yml --dry-run` | Solves but installs nothing — proves the env is solvable. |
| List all environments | `conda env list` | The active one has a `*`. `conda info --envs` is equivalent. |
| Delete an environment | `conda env remove --name myenv` | Add `--yes` to skip confirmation. Only deletes that env. |

### Enter · leave

```bash
conda activate py312-core      # enter
conda deactivate               # leave (back to base or plain shell)
```

### Inspect what's inside

```bash
conda list --name py312-core            # every package + version in that env
conda list --name py312-core --explicit # exact download URLs (see §7)
```

Leave off `--name` to inspect the *currently active* environment.

### Add a package (sparingly!)

```bash
conda install --name py312-core --channel conda-forge rich
```

> ⚠️ In this repo the **`.yml` is the source of truth**. Prefer editing the file and running
> `conda env update` ([§6](#6-environment-files-yml)) so your change is recorded.
> Install several packages in **one** command, not one at a time — conda then solves them
> together and avoids conflicts.

### Run one command inside an env without activating

```bash
conda run --name py312-core python --version
conda run --no-capture-output -n py312-core python scripts/verify-env.py -p 3.12 --env core
```

`--no-capture-output` (short `-s`) shows the program's output **live** instead of only at the
end. The repo's automation uses this form.

---

## 6. Environment files (`.yml`)

A recipe looks like this (shortened from the repo):

```yaml
name: py312-core
channels:
  - conda-forge
dependencies:
  - python=3.12.*
  - numpy
  - pandas
```

### Update an environment to match its recipe

```bash
conda env update --file python/3.12/environments/01-core.yml --prune
```

`--prune` **removes** packages that are no longer listed in the file, so the env matches the
recipe exactly. The repo's `update-env` script uses it.

> ⛔ **Never use `--prune` when deliberately *layering* several files into one env** (the
> "all-in-one" recipe in the [README](../README.md#building-one-all-in-one-environment-iterative-layering)).
> Each new file would delete the previous file's packages. For layering, use
> `conda env update -n <target> -f <file>` **without** `--prune`.

Using `-n <name>` together with `-f <file>` **overrides** the file's `name:` line — that is
what makes layering onto one shared env possible.

### Export what you have

```bash
conda env export --name py312-core > frozen.yml               # exact versions + build strings (same OS only)
conda env export --name py312-core --no-builds > nobuild.yml  # versions only — more portable
conda env export --name py312-core --from-history > intent.yml # only what YOU asked for
conda list --name py312-core --explicit > explicit.txt        # exact URLs: strongest rebuild
```

The redirect `> file` saves the output to a file. `./scripts/export-env.sh <env>` writes the
first, second and last of these for you.

---

## 7. Reproducible rebuilds (lockfiles)

A `.yml` says **what you want** ("numpy"). A **lockfile** records **exactly what you got**
(the precise download URL and hash of every package), so a rebuild months later is identical
and skips solving.

This repo ships them at `python/<ver>/lockfiles/linux-64/*.conda.lock`.

```bash
# Rebuild an environment from a lockfile (Linux x86-64 lockfile)
conda create --name py312-core --file python/3.12/lockfiles/linux-64/01-core.conda.lock

# …or with conda-lock (required for the locks that contain pip packages)
conda-lock install --name py312-tools python/3.12/lockfiles/linux-64/05-tools.conda.lock
```

> **Which one?** Plain `conda create --file` reads only the conda part of an explicit lock and
> **ignores `# pip …` lines**. The lockfile README lists which repo locks carry pip
> packages; use `conda-lock install` for those
> ([details](../python/3.12/lockfiles/README.md)).
> A lock is **platform-specific**: a `linux-64` lock won't rebuild on Windows or Apple Silicon.

Deeper explanation: [Lockfiles — explained](../python/3.12/lockfiles/LOCKFILES-EXPLAINED.md).

---

## 8. Housekeeping

### Free disk space

```bash
conda clean --all --dry-run    # show what WOULD be deleted (safe)
conda clean --all --yes        # delete downloaded tarballs, index cache, unused packages
```

`--all` = everything cleanable; `--dry-run` = pretend; `--yes` = don't ask. Environments you
use are **not** removed. Repo helper: `./scripts/clean-env.sh` (dry-run by default; add `--yes`).

### See what could be upgraded

```bash
conda update --all --name py312-core --dry-run   # list available upgrades, change nothing
```

Repo helper: `./scripts/compare-envs.sh --outdated py312-core`.

### Compare two environments

```bash
conda list --name env_a    # then the same for env_b, and diff the two lists
```

Repo helper: `./scripts/compare-envs.sh env_a env_b` does the diff for you.

### Read the settings

```bash
conda config --show channels
conda config --show channel_priority
conda info --envs
conda --version
```

---

## 9. mamba and micromamba

Same recipes, **much faster solver**.

| Tool | What it is | Use it when |
|------|------------|-------------|
| **conda** | The original. | Default; always works. |
| **mamba** | A drop-in faster front-end: same commands, just replace the word `conda`. | You have it installed (conda ≥ 23.10 already uses the fast *libmamba* solver by default, so the gap is small). |
| **micromamba** | A tiny **stand-alone** program; needs **no** prior conda install and no `base` env. | CI, Docker, throwaway or "zero-install" setups. |

### mamba (identical syntax)

```bash
mamba env create --yes --file python/3.12/environments/01-core.yml
mamba install --yes conda-lock
```

The repo's `create-env` / `update-env` scripts **automatically pick mamba if it exists**,
otherwise conda. Force a choice on Linux/macOS with `CONDA_EXE=mamba ./scripts/create-env.sh …`.

### micromamba

Install: see the [official installation guide](https://mamba.readthedocs.io/en/latest/installation/micromamba-installation.html)
(or let `./scripts/micromamba-env.sh` download a local copy for you). Then:

```bash
micromamba --version
micromamba create --yes --name py312-core --file python/3.12/environments/01-core.yml
micromamba run --name py312-core python scripts/verify-env.py -p 3.12 --env core
micromamba install --yes --name base --file env.yml     # used inside Dockerfile.conda
micromamba clean --all --yes                            # shrink a Docker image
```

**Root prefix.** micromamba keeps its environments and cache under **`MAMBA_ROOT_PREFIX`**.
The repo script sets it to `python/<ver>/.micromamba` unless you set it yourself; deleting
that folder removes everything.

**Activating in a shell** (optional; `micromamba run` doesn't need it):

```bash
eval "$(micromamba shell hook --shell bash)"   # once per shell session
micromamba activate py312-core
```

---

## 10. conda-lock

`conda-lock` is a separate tool that **produces** (and installs) lockfiles for several
platforms.

Install (any one):

```bash
pipx install conda-lock                                  # recommended: isolated
mamba install --yes conda-lock                           # into the active env (what CI does)
conda install --channel conda-forge --name base conda-lock
```

Generate an **explicit** lock for one platform, as this repo's `update-lockfiles` workflow does:

```bash
conda-lock lock --file python/3.12/environments/01-core.yml --platform linux-64 --kind explicit
```

| Flag | Meaning |
|------|---------|
| `--file` / `-f` | The input recipe. |
| `--platform` / `-p` | Target platform (`linux-64`, `win-64`, `osx-arm64`, …); repeat for several. |
| `--kind explicit` | Emit the flat URL list (`conda-<platform>.lock`) that `conda create --file` understands. |

Install from a lock: `conda-lock install --name <env> <lockfile>` (or `--prefix <path>`).

> Don't hand-edit files under `lockfiles/`. Regenerate them — easiest via the GitHub
> **Actions → update-lockfiles** workflow ([guide](github-workflows.md)).

---

## 11. Jupyter kernels

To use an environment as a kernel in JupyterLab/Notebook:

```bash
conda run --name py312-ml python -m ipykernel install --user --name py312-ml --display-name "Python (py312-ml)"
```

`--user` installs the kernel for your account only. Or use the helper, which also installs
`ipykernel` (via `conda install --yes -n <env> -c conda-forge ipykernel`) if it's missing:

```bash
./scripts/register-kernel.sh py312-ml            # add
./scripts/register-kernel.sh --list              # show kernels
./scripts/register-kernel.sh --remove py312-ml   # remove
```

---

## 12. Which repo script runs which command

Run from the repo root. Bash scripts end in `.sh`; PowerShell twins end in `.ps1`
(`.\scripts\name.ps1`). Guide: [The helper scripts](scripts.md).

| Script | Does | Underlying command(s) |
|--------|------|-----------------------|
| `doctor` | Health-check your tools | `conda config --show channels`, `… channel_priority`, `<tool> --version` |
| `create-env -p 3.12 01-core` | Build an env | `mamba`/`conda env create --yes --file …` |
| `update-env -p 3.12 01-core` | Sync env to its recipe | `mamba`/`conda env update --file … --prune` |
| `export-env <env>` | Snapshot an env | `conda env export` (±`--no-builds`), `conda list --explicit` |
| `clean-env [--yes]` | Free disk space | `conda clean --all --dry-run` / `--yes` |
| `compare-envs a b` · `--outdated e` | Diff / find upgrades | `conda list --name`, `conda update --all --dry-run` |
| `test-env -p 3.12 01-core` | Build + verify like CI | `mamba env create --yes --file …`, `conda run --no-capture-output -n … python scripts/verify-env.py …` |
| `micromamba-env -p 3.12 01-core` | Zero-install build | `micromamba create --yes --name … --file …`, `micromamba run --name …` |
| `register-kernel <env>` | Jupyter kernel | `conda env list`, `conda install`, `conda run … ipykernel install --user` |
| `audit-env --name <env>` | Security + hygiene audit | `conda run --no-capture-output -n … python -m pip freeze` |
| `verify-env.py` | Import check | *(Python; run inside the env)* |

---

## 13. Troubleshooting

| Symptom | Likely cause → fix |
|---------|--------------------|
| `conda: command not found` | Not initialised → `conda init`, restart terminal. |
| `conda activate` complains about init | Same → `conda init <your-shell>`, restart. |
| `PackagesNotFoundError` / `UnsatisfiableError` | Channel not set or a version clash → [§3](#3-one-time-setup-channels), then see [troubleshooting](troubleshooting.md). Try `--dry-run` first. |
| Solve takes forever | Use `mamba` (or a recent conda). |
| `EnvironmentNameNotFound` | Typo → check `conda env list`. |
| Packages vanished after `env update` | You used `--prune` on a layered env → rebuild without it. |
| Lock won't install on my OS | Locks are per-platform → generate one for yours ([§10](#10-conda-lock)). |
| Disk is full | `conda clean --all --dry-run`, then `--yes`. |
| `pip install` broke my conda env | Avoid mixing; run `./scripts/audit-env.sh --name <env>` to find clashes. |

More: [troubleshooting](troubleshooting.md) · [FAQ](faq.md).

---

## 14. Cheat sheet

```bash
# setup (once)
conda init                                  && conda config --add channels conda-forge
conda config --set channel_priority strict

# lifecycle
conda env create -f FILE.yml                # build      (add --dry-run to preview)
conda activate NAME                         # enter
conda deactivate                            # leave
conda env list                              # what exists
conda list -n NAME                          # what's inside
conda run -n NAME <cmd>                     # one-off, no activation
conda env update -f FILE.yml --prune        # sync to recipe
conda env remove -n NAME                    # delete

# share / reproduce
conda env export -n NAME --no-builds > env.yml
conda list -n NAME --explicit > explicit.txt
conda create -n NAME --file X.conda.lock    # rebuild from a lock
conda-lock install -n NAME X.conda.lock     # rebuild (locks with pip parts)

# housekeeping
conda clean --all --dry-run                 # then --yes
conda update --all -n NAME --dry-run
```

---

## 15. Sources

Commands and flags in this manual were checked against the official documentation **and the
installed tools' own `--help`** (conda 26.1, micromamba 2.6):

- conda — [command reference](https://docs.conda.io/projects/conda/en/stable/commands/index.html) ·
  [managing environments](https://docs.conda.io/projects/conda/en/stable/user-guide/tasks/manage-environments.html)
- mamba / micromamba — [micromamba user guide](https://mamba.readthedocs.io/en/latest/user_guide/micromamba.html) ·
  [installation](https://mamba.readthedocs.io/en/latest/installation/micromamba-installation.html)
- conda-lock — [documentation](https://conda.github.io/conda-lock/) ·
  [README](https://github.com/conda/conda-lock)
- Miniforge — [conda-forge/miniforge](https://github.com/conda-forge/miniforge)

Next: the [uv manual](uv-manual.md).
