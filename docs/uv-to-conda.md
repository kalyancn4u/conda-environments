# uv-to-conda — turn a `requirements.txt` into a Conda `environment.yml`

<sub>📍 [conda-environments](../README.md) › [docs](README.md) › **uv-to-conda**</sub>

This is a **complete-novice → mastery** guide to one small, sharp tool in this repo:
[`scripts/uv-to-conda.py`](../scripts/uv-to-conda.py). By the end you'll understand
*what problem it solves*, *why it exists*, and how to drive it with confidence — even
if you've never used pip, conda, or uv before.

> **Reference vs. teaching.** This page **teaches**. The terse, look-it-up
> **reference** (every flag, exit codes, the mapping table) lives next to the code in
> [`scripts/README.md`](../scripts/README.md). Read this first; keep that open as a
> cheat sheet.

> **New to conda and virtual environments entirely?** Skim
> [conda-vs-uv.md](conda-vs-uv.md) first — it explains the *tools*. This guide assumes
> only that you can open a terminal and run a command.

**Contents**

1. [The problem, told as a story](#1-the-problem-told-as-a-story)
2. [The 60-second mental model](#2-the-60-second-mental-model)
3. [The words you need (mini-glossary)](#3-the-words-you-need-mini-glossary)
4. [Prerequisites — install uv](#4-prerequisites--install-uv)
5. [Your first conversion (step by step)](#5-your-first-conversion-step-by-step)
6. [Reading the file it produced](#6-reading-the-file-it-produced)
7. [The two strategies: `latest` vs `stable`](#7-the-two-strategies-latest-vs-stable)
8. [Package names: why PyPI and conda disagree](#8-package-names-why-pypi-and-conda-disagree)
9. [When things go wrong (troubleshooting)](#9-when-things-go-wrong-troubleshooting)
10. [Growing up: using it from Python (batch)](#10-growing-up-using-it-from-python-batch)
11. [How it fits this repository](#11-how-it-fits-this-repository)
12. [One-page cheat sheet](#12-one-page-cheat-sheet)
13. [Where to go next](#13-where-to-go-next)

---

## 1. The problem, told as a story

Imagine a colleague hands you a file called `requirements.txt`. It looks like this:

```text
numpy==1.26.0
pandas==2.1.0
scikit-learn
matplotlib
jupyter
```

Two things are true about this file:

- Some lines are **exact** — `numpy==1.26.0` says "give me *precisely* version 1.26.0."
- Some lines are **vague** — `scikit-learn` says "give me scikit-learn… *some* version,
  I don't care which."

That file speaks the language of **pip** (the Python Packaging Index world). But this
repository lives in the world of **conda**, which wants a *different* file —
`environment.yml` — written in a *different* dialect. You can't hand a `requirements.txt`
to `conda env create` and expect it to work well.

So you have two chores:

1. **Translate** the file from pip's dialect to conda's dialect.
2. **Decide a version** for every vague line (what *exactly* does `scikit-learn` mean
   today?).

Doing this by hand is tedious and easy to get wrong. **`uv-to-conda.py` does both for
you, in about a second.** It keeps your exact pins exactly as written, asks a
lightning-fast resolver called **uv** to pick concrete versions for the vague lines, and
writes you a clean, ready-to-use `environment.yml`.

That's the whole tool. Everything below is detail.

---

## 2. The 60-second mental model

Picture two neighbouring countries that speak related-but-different languages:

| | **pip world** | **conda world** |
| :--- | :--- | :--- |
| The shopping list is called | `requirements.txt` | `environment.yml` |
| A pin looks like | `numpy==1.26.0` (double `=`) | `numpy=1.26.0` (single `=`) |
| Installs from | PyPI (pypi.org) | conda channels (conda-forge) |
| A package might be named | `opencv-python` | `opencv` |
| The tool that installs | `pip` / `uv` | `conda` / `mamba` |

`uv-to-conda.py` is the **translator standing at the border**. You give it the pip-world
shopping list; it hands back the conda-world shopping list — same intent, correct dialect,
every vague item pinned to a real version.

```text
requirements.txt  ──►  [ uv-to-conda.py ]  ──►  environment.yml
 (pip dialect,          1. keep exact pins        (conda dialect,
  some lines vague)      2. uv picks versions       every line pinned)
                         3. fix the names
                         4. write conda file
```

---

## 3. The words you need (mini-glossary)

You'll meet these five words. That's all the jargon there is.

- **Pinned** — a line that names an exact (or bounded) version: `numpy==1.26.0`,
  `flask>=2.0`. You are *pinning it down*.
- **Unpinned** — a line that's just a name: `scikit-learn`. It floats; *something* has to
  choose a version for it.
- **Resolve** — the act of choosing concrete versions that all fit together. Packages
  depend on other packages, so this is a puzzle. **uv** solves that puzzle very fast.
- **Transitive dependency** — a package you didn't ask for, but that the ones you *did*
  ask for need. Ask for `matplotlib` and you also get `pillow`, `fonttools`,
  `contourpy`, … Real resolution pins **all** of them, so your final file is long (~100+
  lines) even though your input had five. That is correct and good — it's what makes the
  environment reproducible.
- **Strategy** — *how* uv picks versions when a line is unpinned. This tool offers two:
  `latest` and `stable`. That's [section 7](#7-the-two-strategies-latest-vs-stable).

---

## 4. Prerequisites — install uv

You need two things:

1. **Python 3.8 or newer** — you almost certainly already have it (`python --version`).
2. **uv** — *only* if your `requirements.txt` has unpinned lines. A file where *every*
   line is pinned is converted without uv at all.

Install uv once:

```bash
pip install uv
```

Check it's there:

```bash
uv --version
```

> **What is uv?** A modern, extremely fast replacement for pip's resolver, written in
> Rust. Here we use exactly one of its powers: `uv pip compile`, which reads a list of
> package names and works out concrete, mutually-compatible versions. You never call uv
> directly — the script does.

---

## 5. Your first conversion (step by step)

The repo ships example inputs so you can try this immediately. From the repository root:

**Linux / macOS**

```bash
python scripts/uv-to-conda.py \
    -i scripts/examples/requirements.latest.txt \
    -o my-first-environment.yml \
    -n my-first-env \
    -v
```

**Windows PowerShell**

```powershell
python scripts\uv-to-conda.py `
    -i scripts\examples\requirements.latest.txt `
    -o my-first-environment.yml `
    -n my-first-env `
    -v
```

What the flags mean (the four you'll use 90% of the time):

| Flag | Reads as | In this run |
| :--- | :--- | :--- |
| `-i` | **in** — the requirements file to read | the example input |
| `-o` | **out** — the environment file to write | `my-first-environment.yml` |
| `-n` | **name** — what to call the conda environment | `my-first-env` |
| `-v` | **verbose** — narrate each step | on |

**Expected output** (versions will differ by date — that's normal):

```text
[uv-to-conda] Parsed 2 pinned package(s) and 3 unpinned package(s).
[uv-to-conda] Resolving 3 unpinned package(s) using 'latest' strategy...
[uv-to-conda] Running uv resolution with strategy: latest
[uv-to-conda] Resolved 110 package(s).
[uv-to-conda] Writing 112 dependency line(s) to my-first-environment.yml:
...
Wrote Conda environment file: my-first-environment.yml
Create the environment with:

    conda env create -f my-first-environment.yml
```

🎉 You just translated a pip file into a conda file. Two pinned packages stayed exactly as
written; three vague ones became a fully-pinned, ~110-package environment.

To actually build the environment (optional, needs conda and can take a few minutes):

```bash
conda env create -f my-first-environment.yml
conda activate my-first-env
```

---

## 6. Reading the file it produced

Open `my-first-environment.yml`. Here's a trimmed version with every part labelled:

```yaml
name: my-first-env          # ← the environment's name (your -n)
channels:                   # ← where conda downloads from
  - conda-forge
dependencies:               # ← the shopping list
  - python=3.12             # ← Python itself, always first
  - numpy=1.26.0            # ← your PINNED line, kept exactly (note: single '=')
  - pandas=2.1.0            # ← your other pin
  - scikit-learn=1.9.0      # ← was vague; uv chose a version
  - matplotlib=3.11.1       # ← was vague; uv chose a version
  - contourpy=1.3.3         # ← you never asked for this — it's a TRANSITIVE dep
  - pillow=12.3.0           # ← …and so is this
  - ...                     #   (~100 more, all pinned, all needed)
  - pip                     # ← makes 'pip' available inside the env
  - pip:                    # ← escape hatch for PyPI-only packages:
      # - some-pypi-only-package==1.2.3
```

Three things worth noticing:

1. **Your pins are untouched.** `numpy==1.26.0` became `numpy=1.26.0` — the *only* change
   is `==` → `=`, because that's how conda spells an exact pin. Same version, conda dialect.
2. **The file is long.** That's the transitive closure ([§3](#3-the-words-you-need-mini-glossary))
   — every dependency of every dependency, pinned. Long = reproducible.
3. **There's a `pip:` section.** A few packages have no conda build. If you ever need one,
   uncomment a line there and conda will pip-install it *inside* the environment.

---

## 7. The two strategies: `latest` vs `stable`

This is the heart of the tool. When a line is unpinned, *which* version should uv pick?
There's no single right answer, so you choose a **strategy** with `-s`.

### A story to make it concrete

It's Friday. A new version of a library came out **this morning**. Do you want it?

- **On your laptop, exploring?** Sure — give me the newest of everything. → **`latest`**
- **Shipping to production on Monday?** Absolutely not — that version is hours old and
  untested in the wild. Give me the newest version that's had *time to prove itself*. →
  **`stable`**

### `latest` (the default)

> "Newest compatible version of everything."

```bash
python scripts/uv-to-conda.py -i requirements.txt -o environment.yml -n dev
```

Best for: development, experiments, staying current.

### `stable` (production-safe)

> "The newest version that's already been battle-tested — nothing bleeding-edge, no
> pre-releases."

```bash
python scripts/uv-to-conda.py -i requirements.txt -o environment.yml -n prod -s stable
```

Under the hood, `stable` tells uv two things:

- `--exclude-newer <a date ~90 days ago>` — **ignore anything released in the last 90
  days.** A release that has survived three months in the wild has had its worst bugs
  found and fixed by other people already.
- `--prerelease disallow` — **never** an alpha, beta, or release-candidate version.

You can widen or narrow the 90-day window with `--exclude-days` (e.g. `--exclude-days 180`
for an even more conservative six months).

### Seeing the difference

Run both strategies on the same input and compare. Using the shipped examples, real
resolutions looked like this:

| package | `latest` picked | `stable` picked |
| :--- | :--- | :--- |
| matplotlib | `3.11.1` | `3.10.9` *(older, proven)* |
| scipy | `1.18.1` | `1.17.1` |
| ipython | `9.17.1` | `9.14.1` |
| numpy *(pinned)* | `1.26.0` | `1.26.0` *(pins never move)* |

The committed example outputs
([`environment.latest.yml`](../scripts/examples/environment.latest.yml) and
[`environment.stable.yml`](../scripts/examples/environment.stable.yml)) are the genuine,
full results — open them side by side.

> **A subtle-but-important design note.** You might expect `stable` to mean "the *oldest*
> version." It does **not**, and deliberately so. Asking for the oldest version of an
> *unpinned* package gives you the oldest version *ever published* — for `scikit-learn`
> that's a 2011-era release that no longer even builds. "Oldest" is a trap; "newest that's
> had time to settle" is what production actually wants. The
> [reference README](../scripts/README.md#stable) explains the full reasoning.

---

## 8. Package names: why PyPI and conda disagree

The same project can have **two different names** depending on where you install it from:

| You'd `pip install` … | but conda calls it … |
| :--- | :--- |
| `opencv-python` | `opencv` |
| `Pillow` | `pillow` |
| `PyYAML` | `pyyaml` |

If the tool copied names verbatim, conda wouldn't find them. So it keeps a small built-in
**translation table** (`DEFAULT_MAPPING` in the script) and fixes these automatically.

Need to teach it a name it doesn't know? Write a tiny JSON file:

```json
{
  "my-internal-lib": "my-conda-lib",
  "opencv-python": "opencv"
}
```

…and pass it with `-m`:

```bash
python scripts/uv-to-conda.py -i requirements.txt -m my-names.json
```

Your entries win over the built-ins. (The look-up is smart about case and dashes vs.
underscores, so `Foo.Bar` and `foo-bar` are treated as the same project.)

---

## 9. When things go wrong (troubleshooting)

Every error the tool prints is meant to tell you exactly what to do. The common ones:

| You see… | What it means | Fix |
| :--- | :--- | :--- |
| `ERROR: 'uv' was not found` | uv isn't installed (and you have unpinned lines) | `pip install uv` |
| `ERROR: input file not found` | the `-i` path is wrong | check the path; run from the repo root |
| `invalid peer certificate: UnknownIssuer` (from uv) | you're behind a corporate proxy that intercepts HTTPS | add **`--system-certs`** — it tells uv to trust your computer's certificate store |
| `ERROR: uv failed to resolve...` | the version puzzle has no solution (two packages want incompatible things) | read uv's message printed below it; loosen or change a pin |
| the first package name looks garbled | your file was saved with a hidden "BOM" marker | harmless — the tool strips it automatically; just re-run |

The `--system-certs` one is worth remembering — on a locked-down work laptop it's often
the difference between "nothing works" and "everything works":

```bash
python scripts/uv-to-conda.py -i requirements.txt -o environment.yml --system-certs
```

> **Safe by design.** However a run ends — success, error, or you hit Ctrl-C — the tool
> always cleans up its temporary files and reports a clear exit code (`0` = success,
> `1` = something went wrong). You never have to tidy up after it.

---

## 10. Growing up: using it from Python (batch)

Once you're comfortable at the command line, you can call the tool **from Python** to
convert *many* files at once — say, one environment per team. Because the filename has a
hyphen, you import it with `importlib` (a two-line incantation; just copy it):

```python
import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location("u2c", "scripts/uv-to-conda.py")
u2c = importlib.util.module_from_spec(spec)
spec.loader.exec_module(u2c)          # now u2c is the tool, as a module

for team in ("core", "ml", "web"):
    u2c.convert(
        input_path=Path(f"reqs/{team}.txt"),
        output_path=Path(f"envs/{team}.yml"),
        env_name=team,
        strategy="stable",            # production defaults for everyone
    )
```

`convert()` is the whole tool in one function. The smaller building blocks
(`parse_requirements`, `resolve_with_uv`, `generate_conda_yml`, `load_package_mapping`)
are available too if you want to assemble something custom. See the
[reference](../scripts/README.md#programmatic-use-batch-processing).

---

## 11. How it fits this repository

`uv-to-conda.py` is a **helper for authoring** environment files — it gets you *from a pip
requirements list to a first draft* of a conda `environment.yml`. Here's where it sits in
the bigger picture this repo teaches:

```text
  a pip requirements.txt
          │
          │   uv-to-conda.py   ◄── you are here
          ▼
  a draft environment.yml  ──►  curate by hand  ──►  python/<ver>/environments/*.yml
                                (add system libs,          │
                                 group sensibly)            │  conda-lock / uv compile
                                                            ▼
                                                    lockfiles/  (exact, reproducible)
```

Practical tips for using it *inside* this project:

- **Match the Python version** to the tree you're targeting: `-p 3.10` or `-p 3.12`
  (default). See [`python/3.12/`](../python/3.12/) and [`python/3.10/`](../python/3.10/).
- **The draft is a starting point, not the finished file.** System-level and non-Python
  pieces (`cudatoolkit`, compilers, `openssl`) don't live in `requirements.txt` and won't
  appear — add them by hand, the way the curated
  [environments](../python/3.12/environments/) do. See
  [package-selection.md](package-selection.md) for the naming gotchas.
- **Then lock it.** Once an environment works, capture it exactly with the repo's lockfile
  workflow — [Lockfiles, explained](../python/3.12/lockfiles/LOCKFILES-EXPLAINED.md).
- **`stable` pairs naturally with production/CI-CD** — the same audience as
  [uv requirements](../python/3.12/lockfiles/requirements/README.md) and
  [user-workflows.md](user-workflows.md).

---

## 12. One-page cheat sheet

```bash
# The 90% command — dev, newest versions
python scripts/uv-to-conda.py -i requirements.txt -o environment.yml -n myenv

# Production — battle-tested versions, no pre-releases
python scripts/uv-to-conda.py -i requirements.txt -o environment.yml -n prod -s stable

# Behind a corporate proxy? add:
                                                               --system-certs

# Target Python 3.10 instead of 3.12:
                                                               -p 3.10

# Teach it custom package names:
                                                               -m names.json

# Then build it:
conda env create -f environment.yml
```

| Flag | Long form | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `-i` | `--input` | `requirements.txt` | file to read |
| `-o` | `--output` | `environment.yml` | file to write |
| `-n` | `--name` | `myenv` | environment name |
| `-p` | `--python` | `3.12` | target Python version |
| `-c` | `--channels` | `conda-forge` | conda channels (comma-separated) |
| `-s` | `--strategy` | `latest` | `latest` or `stable` |
| `-m` | `--mapping` | — | JSON of custom PyPI→conda names |
| `-v` | `--verbose` | off | narrate each step |
| | `--exclude-days` | `90` | (stable) age a release must reach |
| | `--system-certs` | off | trust OS certs (proxies) |

Full reference (exit codes, the built-in mapping, internals):
[`scripts/README.md`](../scripts/README.md).

---

## 13. Where to go next

You now have mastery of this tool. To connect it to the rest of the system:

- **The tools it builds on** — [conda-vs-uv.md](conda-vs-uv.md): conda/mamba/micromamba
  vs. venv + pip/uv, and *why CD favours uv*.
- **What to do with the file you generated** —
  [user-workflows.md](user-workflows.md): the end-to-end cookbook (dev, notebooks,
  production, containers, CI/CD, MLOps).
- **Making it reproducible forever** —
  [Lockfiles, explained](../python/3.12/lockfiles/LOCKFILES-EXPLAINED.md).
- **The design philosophy** — [architecture.md](architecture.md) and
  [package-selection.md](package-selection.md).

Lost? The whole learning path is mapped at [docs/README.md](README.md).

---

<sub>📍 [conda-environments](../README.md) › [docs](README.md) › **uv-to-conda** ·
Reference: [scripts/README.md](../scripts/README.md)</sub>
