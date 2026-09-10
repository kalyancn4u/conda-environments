# The helper scripts — one shared toolset, one `-p` flag

<sub>📍 [conda-environments](../README.md) › [docs](README.md) › **scripts**</sub>

This is a **complete-novice → mastery** guide to the little programs in the repo's
[`scripts/`](../scripts/) folder. They exist so you never have to memorize conda's flags:
each does **one job** with a friendly, predictable interface. By the end you'll know what
every script is for, the *one mental model* that makes them all feel the same, and exactly
how to drive them.

> **Teaching vs. reference vs. recipes.** This page **teaches** (what & why). The terse
> **reference** — every flag, the `-p?` table, exit codes — is
> [`scripts/README.md`](../scripts/README.md). The **recipes** — "I want notebooks / a
> production venv / CI" — are in [user-workflows.md](user-workflows.md). Read this first.

> **Newer to the tools themselves** (what conda/venv/uv even are)? Skim
> [conda-vs-uv.md](conda-vs-uv.md) first. This guide assumes only that you can open a
> terminal.

**Contents**

1. [The problem these scripts solve](#1-the-problem-these-scripts-solve)
2. [The one mental model (read this twice)](#2-the-one-mental-model-read-this-twice)
3. [Why the version is explicit, not guessed](#3-why-the-version-is-explicit-not-guessed)
4. [The `-p` cheat: who needs it](#4-the--p-cheat-who-needs-it)
5. [A tour, grouped by what you're trying to do](#5-a-tour-grouped-by-what-youre-trying-to-do)
6. [Your first session (copy-paste)](#6-your-first-session-copy-paste)
7. [When things go wrong](#7-when-things-go-wrong)
8. [One-page cheat sheet](#8-one-page-cheat-sheet)
9. [Where to go next](#9-where-to-go-next)

---

## 1. The problem these scripts solve

Managing conda environments by hand means memorizing a pile of flags:
`conda env create --file … --yes`, `--prune`, `conda config --set channel_priority
strict`, `conda run -n … python -c "import …"`, and so on. Miss one and you get a slow
solve, a polluted environment, or a "works on my machine" surprise.

The scripts wrap those incantations into **one verb each**:

- "build an environment" → `create-env`
- "check it actually imports" → `verify-env.py`
- "is my machine set up right?" → `doctor`
- …and so on.

They apply the repo's conventions for you (conda-forge, strict priority, sensible
defaults), print friendly errors, and behave the same on Linux, macOS, and Windows.

**One more thing changed recently, and it's the key to everything below:** the scripts
used to be copied into *each* Python version's folder (`python/3.10/scripts/`,
`python/3.12/scripts/`). Now there is **one shared copy** in the top-level
[`scripts/`](../scripts/), and you tell each script which Python version to act on with a
**`-p` flag**. That's the whole idea. The next section makes it concrete.

---

## 2. The one mental model (read this twice)

Three rules cover **every** script:

> **1. They live in one place: `scripts/` at the repository root.**
> **2. You run them from the repository root**, so `./scripts/…` resolves.
> **3. You say which Python tree to act on with `-p <version>`** (e.g. `-p 3.12`).

So a command reads like an English sentence:

```text
./scripts/create-env.sh   -p 3.12   01-core
        │                    │          │
   which tool          which Python   which environment
                          tree
```

- On **Linux/macOS** run the `.sh` file: `./scripts/create-env.sh -p 3.12 01-core`
- On **Windows** run the `.ps1` file: `.\scripts\create-env.ps1 -p 3.12 01-core`
- `.py` files (`verify-env.py`) run anywhere Python does:
  `python scripts/verify-env.py -p 3.12 --env core`

That `-p 3.12` is what points the script at [`python/3.12/`](../python/3.12/); switch it to
`-p 3.10` and the *same command* acts on the [`python/3.10/`](../python/3.10/) tree. The
folder you happen to be standing in never matters — **only `-p` selects the tree.**

---

## 3. Why the version is explicit, not guessed

You might wonder: why type `-p 3.12` every time — couldn't the script just *figure out*
the version?

It used to try. When a copy of each script lived inside `python/3.12/scripts/`, it read
"3.12" from its own folder path. That was clever but fragile, and it stopped working the
moment we merged everything into one shared folder — a single shared script has no version
in *its* path to read.

Making the version an **explicit input** is the honest fix, and it's better on its own
merits:

- **No hidden magic.** What you type is what happens. A command means the same thing no
  matter where you run it from or how the repo is arranged.
- **It's self-documenting.** `-p 3.12` states your intent; the script even checks that
  `python/3.12/` exists and stops with a clear error if you mistype it.
- **One file, every version.** Adding a new tree like `python/3.15/` needs **zero** script
  changes — you just start passing `-p 3.15`. (That's how `3.13` and `3.14` were added.)

This is the same spirit as pinning a version in a lockfile: *say what you mean, don't let
the tool guess.*

---

## 4. The `-p` cheat: who needs it

Not every script touches a version tree, so `-p` isn't universal. There are four cases:

| `-p` rule | Scripts | Why |
| :--- | :--- | :--- |
| **Required** | `create-env`, `update-env`, `verify-env.py`, `test-env`, `micromamba-env` | Their whole job is tied to a tree (`environments/…`, the `py<ver>-` env name, the version to import-check). |
| **Required for the shorthand only** | `setup-venv`, `audit-env` | Passing a bare name like `04-web` needs `-p` to find `python/<ver>/lockfiles/requirements/04-web.txt`. Passing an explicit path, or `--name`/`--venv`, does not. |
| **Optional** | `doctor` | It only inspects your machine. Give `-p` to label the report with a tree context; omit it for a version-neutral check. |
| **None** | `clean-env`, `compare-envs`, `export-env`, `register-kernel` | You hand them a conda **env name** (e.g. `py312-ml`) or nothing; they never look up a tree. |

Rule of thumb: **if a script needs a *file from the repo*, it needs `-p`. If it acts on an
*already-created environment* by name, it doesn't.**

---

## 5. A tour, grouped by what you're trying to do

Every script has both a `.sh` (Linux/macOS) and `.ps1` (Windows) form unless noted;
`.py` runs anywhere. Run from the repo root.

### "Is my machine ready?"
- **`doctor`** — a read-only preflight: which tools are installed (conda/mamba/micromamba/
  uv/pip/docker/git), whether conda-forge + strict priority are set, and whether your shell
  is safe for `uv`/`pip`. Changes nothing. Run it first on any machine.
  ```bash
  ./scripts/doctor.sh                 # version-neutral
  ./scripts/doctor.sh -p 3.12         # labelled for the 3.12 tree
  ```

### "Build / update / check a conda environment" (the daily loop)
- **`create-env`** — create an environment from a `.yml`:
  `./scripts/create-env.sh -p 3.12 01-core`
- **`update-env`** — update an existing env to match its `.yml` (with `--prune`, so removed
  packages are removed): `./scripts/update-env.sh -p 3.12 01-core`
- **`verify-env.py`** — smoke-test that the headline packages import:
  `python scripts/verify-env.py -p 3.12 --env core` (or `--all`, or `--packages numpy pandas`)

### "Compare, snapshot, or clean up"
- **`compare-envs`** — diff two environments, or list upgradable packages
  (`--outdated`). No `-p` (you name the envs): `./scripts/compare-envs.sh py312-core py312-ds`
- **`export-env`** — save an exact snapshot of an environment to `./exports/`. No `-p`:
  `./scripts/export-env.sh py312-core`
- **`clean-env`** — reclaim disk by clearing conda caches (safe; dry-run by default). No
  `-p`: `./scripts/clean-env.sh` then `./scripts/clean-env.sh --yes`

### "Notebooks"
- **`register-kernel`** — expose a conda env as a Jupyter kernel so it appears in the
  notebook kernel picker. No `-p`: `./scripts/register-kernel.sh py312-ml "ML (py3.12)"`

### "No install / throwaway / automation"
- **`micromamba-env`** — create **and** verify an environment with *zero* prior install: if
  `micromamba` isn't present it downloads a single static binary into a local, gitignored
  folder. Great for CI and quick trials:
  `./scripts/micromamba-env.sh -p 3.12 01-core`

### "Production / PyPI (venv, not conda)"
- **`setup-venv`** — build a slim virtual environment from a pinned
  `lockfiles/requirements/*.txt` (prefers `uv`, falls back to `python -m venv`). It always
  targets the venv's own interpreter, so it can never pollute a conda env:
  `./scripts/setup-venv.sh -p 3.12 04-web`

### "Security & CI"
- **`audit-env`** — a `pip-audit` CVE scan **plus** a conda/pip clash check for conda envs.
  `-p` only for the shorthand form:
  `./scripts/audit-env.sh -p 3.12 04-web` · `./scripts/audit-env.sh --name py312-web`
- **`test-env`** — rebuild + verify an environment inside the *same* container CI uses, so
  "passes locally" means "passes in CI" (needs Docker):
  `./scripts/test-env.sh -p 3.12 --all`

### "Turn a pip requirements.txt into a conda environment.yml"
- **`uv-to-conda.py`** — its own tool with its own guide: **[uv-to-conda.md](uv-to-conda.md)**.

---

## 6. Your first session (copy-paste)

From the repository root:

**Linux / macOS**
```bash
# 1. Is my machine ready? (changes nothing)
./scripts/doctor.sh

# 2. Build the daily-driver environment on the 3.12 tree
./scripts/create-env.sh -p 3.12 01-core

# 3. Activate it, then check it imports cleanly
conda activate py312-core
python scripts/verify-env.py -p 3.12 --env core
```

**Windows PowerShell**
```powershell
.\scripts\doctor.ps1
.\scripts\create-env.ps1 -p 3.12 01-core
conda activate py312-core
python scripts\verify-env.py -p 3.12 --env core
```

If `doctor` reports no conda-family tool, install one first (see
[user-workflows §3](user-workflows.md#3-your-first-ten-minutes-any-machine)) or use the
zero-install `micromamba-env` path.

---

## 7. When things go wrong

| You see… | Meaning | Fix |
| :--- | :--- | :--- |
| `-p/--python <X.Y> is required` | you omitted `-p` on a version-aware script | add `-p 3.12` (or your tree) |
| `no such Python tree: python/9.9` | the `-p` value has no matching folder | use a real version, e.g. `-p 3.12` |
| `shorthand '04-web' needs -p …` | you gave `setup-venv`/`audit-env` a bare name without `-p` | add `-p 3.12`, or pass an explicit path |
| `command not found: ./scripts/…` | you're not at the repo root | `cd` to the repository root first |
| `mamba: command not found` (create-env) | no conda-family solver installed | run `doctor`; install Miniforge, or use `micromamba-env` |
| a `.ps1` won't run on Windows | PowerShell execution policy | run from a normal PowerShell; if blocked, `powershell -ExecutionPolicy Bypass -File .\scripts\…` |

> **Safe by design.** `doctor`, `clean-env` (before `--yes`), `compare-envs`, and
> `verify-env.py` change nothing. `setup-venv` refuses to install into an active conda env.
> `clean-env` shows a dry run before deleting.

---

## 8. One-page cheat sheet

```bash
# always from the repo root; -p selects the Python tree
./scripts/doctor.sh                              # what's installed / configured?
./scripts/create-env.sh    -p 3.12 01-core       # build an env from a .yml
./scripts/update-env.sh    -p 3.12 01-core       # update it to match the .yml (prunes)
python scripts/verify-env.py -p 3.12 --env core  # do its packages import?
./scripts/compare-envs.sh  py312-core py312-ds   # diff two envs   (no -p)
./scripts/export-env.sh    py312-core            # snapshot an env (no -p)
./scripts/clean-env.sh                           # free disk (dry run; --yes to act) (no -p)
./scripts/register-kernel.sh py312-ml "ML"       # add a Jupyter kernel (no -p)
./scripts/micromamba-env.sh -p 3.12 01-core      # zero-install create + verify
./scripts/setup-venv.sh    -p 3.12 04-web        # venv + pinned requirements (PyPI)
./scripts/audit-env.sh     -p 3.12 04-web        # CVE scan + conda/pip clash check
./scripts/test-env.sh      -p 3.12 --all         # rebuild + verify in the CI container
```

Windows: swap `./scripts/x.sh` → `.\scripts\x.ps1` (same flags). Full flag reference:
[`scripts/README.md`](../scripts/README.md).

---

## 9. Where to go next

- **Do a real task end-to-end** — [user-workflows.md](user-workflows.md): local dev,
  notebooks, production venvs, containers, testing/QA, security, CI/CD, MLOps.
- **The full flag reference** — [`scripts/README.md`](../scripts/README.md).
- **The tools these wrap** — [conda-vs-uv.md](conda-vs-uv.md).
- **What each environment file contains** — the beginner's guide,
  [python/3.12/GUIDE.md](../python/3.12/GUIDE.md).
- **Convert a pip `requirements.txt`** — [uv-to-conda.md](uv-to-conda.md).

Lost? The whole learning path is mapped at [docs/README.md](README.md).

---

<sub>📍 [conda-environments](../README.md) › [docs](README.md) › **scripts** ·
Reference: [scripts/README.md](../scripts/README.md)</sub>
