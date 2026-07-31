# GitHub workflows (CI) — how this repo automates itself

<sub>📍 [conda-environments](../README.md) › [docs](README.md) › **github-workflows**</sub>

This page explains the **automation that runs inside GitHub** for this repository —
the files in [`.github/workflows/`](../.github/workflows/). Its sibling,
[user-workflows.md](user-workflows.md), covers the commands *you* run at the command
line; this page covers what the **robots run for you** on every push, pull request,
and schedule.

Written **complete-novice → mastery**. If you have never seen a CI pipeline, start at
[§1](#1-github-actions-in-five-minutes-concepts-primer). If you just want to know what
each file does, jump to [§2](#2-the-three-workflows-at-a-glance).

> **Why care?** Continuous Integration (CI) is a safety net. Because these workflows
> run automatically, you get a guarantee that every environment in the repo **still
> solves and still imports**, that every YAML follows the repo's conventions, and that
> the exact-rebuild lockfiles stay fresh — without anyone remembering to check by hand.
> The green/red badges at the top of the [README](../README.md) are the live result.

---

## 1. GitHub Actions in five minutes (concepts primer)

**GitHub Actions** is GitHub's built-in automation system. You describe a pipeline in a
YAML file under `.github/workflows/`; GitHub watches your repo and, when something you
care about happens (a push, a pull request, a scheduled time), it spins up a fresh
computer, checks out your code, and runs the steps you listed. Think of it as a **tireless
assistant that rebuilds and re-tests the project every time anything changes.**

The vocabulary, in plain words (you'll see all of these in the files below):

| Term | What it means |
|------|---------------|
| **Workflow** | One `.yml` file describing an automated process. This repo has **three**. |
| **Event / trigger** (`on:`) | *What* makes a workflow run — a `push`, a `pull_request`, a manual click (`workflow_dispatch`), or a timer (`schedule`). |
| **Job** | A group of steps that runs on one fresh machine. A workflow has one or more jobs; jobs run in parallel unless one `needs` another. |
| **Step** | A single command (`run:`) or a pre-packaged action (`uses:`) inside a job, executed top to bottom. |
| **Runner** | The throwaway virtual machine a job runs on (here: `ubuntu-latest`, a free Linux VM). |
| **Action** (`uses:`) | A reusable building block published by someone else, pinned to a version — e.g. `actions/checkout@v4` clones your repo. |
| **Container** (`container:`) | Run the job *inside* a Docker image instead of the bare runner — this repo uses `condaforge/miniforge3` so `mamba` is already installed. |
| **Matrix** | Run the *same* job many times with different inputs (e.g. one leg per environment), in parallel. |
| **Artifact** | A file a job produces and uploads, so you can download it or hand it to another job. |
| **`workflow_dispatch`** | Adds a **Run workflow** button in the Actions tab for manual, on-demand runs. |
| **`schedule` / cron** | Run on a timer. `cron: "0 6 * * 1"` = 06:00 UTC every Monday. |
| **Path filter** (`paths:`) | Only trigger when *these* files changed — saves minutes by skipping irrelevant pushes. |
| **`permissions:`** | How much the run's automatic `GITHUB_TOKEN` is allowed to do (read-only by default). |
| **`concurrency:`** | Auto-cancel an older run when a newer one starts on the same branch, to save minutes. |

A minimal workflow reads almost like English:

```yaml
name: hello                     # the workflow's display name
on: [push]                      # run it on every push
jobs:
  greet:                        # one job, id "greet"
    runs-on: ubuntu-latest      # on a fresh Linux VM
    steps:
      - uses: actions/checkout@v4        # 1) clone the repo
      - run: echo "Hello, $GITHUB_SHA"   # 2) run a shell command
```

Two log conventions you'll see in this repo's `run:` scripts:

- `echo "::group::title"` … `echo "::endgroup::"` — **folds** a section of the log so it's
  collapsible in the UI.
- `echo "::notice::msg"` / `::warning::` — surfaces an annotation on the run summary.
- `echo "key=value" >> "$GITHUB_OUTPUT"` — passes a value from one step to later steps
  (referenced as `${{ steps.<id>.outputs.key }}`).

That's the whole mental model. The three real workflows below are just longer versions
of the `hello` example.

---

## 2. The three workflows at a glance

| File | Runs when… | What it guarantees | Cost |
|------|-----------|--------------------|------|
| [`validate.yml`](../.github/workflows/validate.yml) | any `.yml` under `python/**` changes (push/PR), or on demand | every environment/template YAML is **well-formed and follows the repo's rules** (conda-forge-only, has a `name:`, deps, and a `python=` pin) | seconds |
| [`test-environments.yml`](../.github/workflows/test-environments.yml) | anything under `python/**` changes (push/PR), or on demand | every environment **actually solves and imports** on Linux, with **no conda/pip clashes** | minutes |
| [`update-lockfiles.yml`](../.github/workflows/update-lockfiles.yml) | **weekly** (Mon 06:00 UTC) or on demand | the exact-rebuild **lockfiles are regenerated** and offered back as a pull request | minutes |

Mnemonic: **validate** = "is the YAML *shaped* right?" (cheap, fast). **test-environments**
= "does it *really work*?" (build it for real). **update-lockfiles** = "keep the *exact*
recipes current." The first two are **gates** (they defend `main`); the third is a
**maintainer** (it proposes updates).

---

## 3. How they fit the development lifecycle

```text
You edit a YAML and open a Pull Request
        │
        ├─►  validate.yml            (seconds)  ─┐
        │      is the YAML valid & conventional?  │  both must be GREEN
        └─►  test-environments.yml   (minutes) ─┘  before you merge
                does every env solve + import?

Every Monday 06:00 UTC (or when you click "Run workflow")
        └─►  update-lockfiles.yml
                regenerate lockfiles ──► open a PR "chore: refresh conda-lock lockfiles"
                                          (you review the version deltas, then merge)
```

The first two run **on your changes** and act as merge gates. The third runs **on a
timer** and does maintenance *for* you. All three can also be launched by hand from the
**Actions** tab (they each declare `workflow_dispatch`).

---

## 4. `validate.yml` — the fast YAML gate

**Goal:** catch obvious mistakes in a second, before spending minutes building anything.
It never installs an environment; it only *reads* the YAML files and checks their shape.

**When it runs** ([`on:`](../.github/workflows/validate.yml)):

```yaml
on:
  push:
    paths: ["python/**/*.yml", ".github/workflows/validate.yml"]
  pull_request:
    paths: ["python/**/*.yml", ".github/workflows/validate.yml"]
  workflow_dispatch:
```

The `paths:` filter means a commit that only touches docs or scripts **won't** trigger
it — minutes are only spent when a `.yml` (or the workflow itself) actually changed.

**What the single job does.** On a plain `ubuntu-latest` runner it: checks out the repo,
sets up Python 3.12, installs `PyYAML`, then runs an inline validator over **every**
`python/**/*.yml`. Each file must pass four rules:

1. It parses as YAML and the top level is a **mapping** (a `key: value` document).
2. It has a non-empty **`name:`** and a non-empty **`dependencies:`** list.
3. Its **`channels:`** is *exactly* `[conda-forge]` — `defaults`/`nvidia` are banned, which
   is what keeps the repo "conda-forge-first".
4. It **pins the Python line** (some `python=…` entry exists).

The heart of it (abridged from the file):

```python
if channels != ["conda-forge"]:
    errors.append(f"channels must be exactly [conda-forge], got {channels}")
if not any(d.split("=")[0].strip() == "python" for d in flat):
    errors.append("no `python=` pin found")
```

**What a failure looks like** in the run log — the offending file and reason are printed,
and the job exits non-zero (red ✗):

```text
INVALID: python/3.12/environments/09-foo.yml
  - channels must be exactly [conda-forge], got ['conda-forge', 'defaults']
  - no `python=` pin found
```

Each file's output is wrapped in a `::group::` so the log stays tidy. Because this gate is
cheap, it gives near-instant feedback on the most common authoring slips.

---

## 5. `test-environments.yml` — build & verify every environment

**Goal:** prove that each environment doesn't just *look* right but **actually solves and
imports** — the real test.

**When it runs:** on push/PR touching anything under `python/**` (not just YAML — scripts
and lockfiles too), or on demand. It also declares:

```yaml
concurrency:
  group: test-environments-${{ github.ref }}
  cancel-in-progress: true
```

so if you push twice quickly, the older run is **cancelled** and only the newest one
finishes — no wasted minutes.

**The matrix.** One job leg per environment, all in parallel:

```yaml
strategy:
  fail-fast: false
  matrix:
    env: [core, ml, dl, web, tools, tf, geo, ts]     # 98-legacy is doc-only, excluded
```

`fail-fast: false` means one environment failing does **not** cancel the others — you see
the full picture (which envs pass, which fail) in a single run. Each leg's short key
(`core`, `ml`, …) maps to a file and env name (`core → 01-core.yml → py312-core`).

**Runs inside a container.** The job sets `container: condaforge/miniforge3:latest`, so
`mamba` (the fast solver) is preinstalled — the same image the local
[`test-env.sh`](../python/3.12/scripts/test-env.sh) uses, so CI and your laptop match.

**The steps, in order:**

1. **Install system deps** — the Miniforge image is minimal, so it `apt-get install`s
   `git` (needed by `actions/checkout` *inside* a container) plus `libgl1`/`libglib2.0-0`
   (the OpenGL/glib libraries that `opencv`/`cv2` loads at import time in the
   deep-learning envs). This is a great example of *why* a green build sometimes needs
   OS-level libraries, not just Python packages.
2. **Checkout** the repo.
3. **Resolve** the env file, env name, and verify key from the matrix value via a `case`
   statement, writing them to `$GITHUB_OUTPUT` for later steps.
4. **Create environment** — `mamba env create --yes --file <the resolved yml>`.
5. **Verify imports** — runs [`verify-env.py`](../python/3.12/scripts/verify-env.py)
   with the env's key, which imports each headline package and exits non-zero on any
   failure.
6. **Check for conda/pip clashes** — an inline Python check that fails if the *same*
   package was installed from *both* conda and pip (an ABI hazard). This is the exact
   check that [`audit-env`](user-workflows.md#5h-security-testing-audit-env) runs locally.

**Why Linux-only?** Deliberate, for cost. The comment in the file spells it out:

> Public repos get unlimited free Linux minutes; private repos bill Linux ×1 vs
> Windows ×2 / macOS ×10 against the free quota.

Cross-platform support (win-64 / osx-arm64) is *documented* in
[compatibility.md](compatibility.md); Linux is the CI proof-of-solvability. A passing run
means all eight environments built and imported cleanly on a fresh machine.

---

## 6. `update-lockfiles.yml` — keep exact rebuilds fresh

**Goal:** the human-readable `*.yml` files capture *intent* (loosely pinned, so they drift
as conda-forge updates). The **lockfiles** capture the *exact* set of packages for a
byte-for-byte rebuild. This workflow regenerates them and opens a PR so a human reviews the
version changes before they land. (Background: [lockfiles — explained](../python/3.12/lockfiles/LOCKFILES-EXPLAINED.md).)

**When it runs:**

```yaml
on:
  workflow_dispatch:
    inputs:
      platforms:
        description: "Space-separated platforms to lock (linux-64, win-64, osx-arm64)"
        default: "linux-64"
  schedule:
    - cron: "0 6 * * 1"     # every Monday 06:00 UTC
```

Two ways to trigger: **manually** (with a `platforms` input — defaults to the quick
`linux-64`), or **automatically** every Monday. Reading cron `0 6 * * 1`: fields are
`minute hour day-of-month month day-of-week`, so *minute 0, hour 6, any day, any month,
weekday 1 (Monday)*, in UTC.

**Permissions.** Unlike the two gates (which need only read access), this workflow *writes*
— it opens a pull request — so it declares the least privilege needed:

```yaml
permissions:
  contents: write
  pull-requests: write
```

**Two jobs, chained.**

**Job 1 — `lock`** (a matrix over all 8 environments **and** all 6 templates, 14 targets,
inside the same Miniforge container): installs `conda-lock`, then for each requested
platform generates an *explicit* lockfile and moves it into
`python/3.12/lockfiles/<platform>/<name>.conda.lock`. Two nuances worth understanding:

- **TensorFlow is skipped on `win-64`** — there is no conda-forge TF build for Windows, so
  `06-tensorflow` and the `all-in-one-tflow` template emit a `::notice::` and move on
  instead of failing.
- Every result is also **uploaded as an artifact**, so you can download the lockfiles from
  the run even if PR creation is restricted by repo settings.

```yaml
- name: Generate lockfiles
  run: |
    for p in $platforms; do
      conda-lock lock --file "$src" --platform "$p" --kind explicit \
        && mv -f "conda-$p.lock" "python/3.12/lockfiles/$p/$name.conda.lock"
    done
```

**Job 2 — `open-pr`** (`needs: lock`, so it waits for all matrix legs): downloads every
lockfile artifact and uses `peter-evans/create-pull-request` to open/refresh a PR on the
branch **`chore/update-lockfiles`** titled *"chore: refresh conda-lock lockfiles"*. You
review the version deltas, then merge.

**How to run it yourself:** repo → **Actions → update-lockfiles → Run workflow**, optionally
typing the platforms (e.g. `linux-64 osx-arm64`). That is exactly the path the
[root README](../README.md#lockfiles-exact-reproducible-rebuilds) recommends.

---

## 7. Running and reading workflows (the Actions tab)

Everything above is observable in the browser:

- **See runs:** repo → **Actions** tab. The left sidebar lists the three workflows; click
  one to see its run history. Green ✓ = passed, red ✗ = failed, yellow = in progress.
- **Read a run:** click a run to see its **jobs** (and, for matrix workflows, one row per
  leg — e.g. `core (linux-64)`, `ml (linux-64)`, …). Click a job to expand its **steps**;
  click a step to read its log. `::group::` sections are collapsible.
- **Run on demand:** open a workflow that has `workflow_dispatch` and click **Run
  workflow** (top-right). For `update-lockfiles` you can fill in the `platforms` input.
- **Re-run:** a failed run has **Re-run all jobs** / **Re-run failed jobs** buttons —
  handy when a failure was a flaky network blip.
- **Badges:** the README shows live status badges. The URL pattern is
  `…/actions/workflows/<file>.yml/badge.svg`; clicking a badge jumps to that workflow's
  runs. A red badge on `main` is the fastest signal that something regressed.
- **Branch protection (optional):** a maintainer can mark `validate` and
  `test-environments` as **required status checks** so a PR literally cannot be merged
  until both are green.

---

## 8. Reproduce the CI locally (don't wait on GitHub)

Every gate can be run on your own machine first, so you push already-green:

```bash
# validate.yml — the same four conventions, over every YAML (needs PyYAML):
python - <<'PY'
import glob, yaml, sys
bad = 0
for f in glob.glob("python/**/*.yml", recursive=True):
    d = yaml.safe_load(open(f, encoding="utf-8"))
    if (d.get("channels") != ["conda-forge"]
            or not d.get("name") or not d.get("dependencies")):
        print("INVALID:", f); bad = 1
sys.exit(bad)
PY

# test-environments.yml — build + verify in the SAME miniforge container (needs Docker):
./python/3.12/scripts/test-env.sh 01-core      # one env   (Windows: .\scripts\test-env.ps1)
./python/3.12/scripts/test-env.sh --all        # every env

# …or without Docker, the zero-install path builds + verifies the same way:
./python/3.12/scripts/micromamba-env.sh 01-core

# update-lockfiles.yml — generate a lock locally with conda-lock:
conda-lock lock --file python/3.12/environments/01-core.yml --platform linux-64 --kind explicit
```

The full command-line playbook — including the conda/pip-clash and CVE checks — lives in
[user-workflows.md](user-workflows.md) (see its
[§5G Testing & QA](user-workflows.md#5g-testing--qa),
[§5H Security](user-workflows.md#5h-security-testing-audit-env), and
[§5I CI/CD](user-workflows.md#5i-cicd--putting-it-together)).

---

## 9. Security & cost model

The workflows are written to be **cheap and least-privilege** — worth understanding before
you copy them elsewhere:

- **Least privilege.** `validate` and `test-environments` declare no `permissions:`, so their
  `GITHUB_TOKEN` is effectively read-only. Only `update-lockfiles` grants `contents: write`
  + `pull-requests: write`, and *only* because it must open a PR.
- **Pinned actions.** Third-party building blocks are pinned to a major version
  (`actions/checkout@v4`, `actions/setup-python@v5`, `peter-evans/create-pull-request@v6`)
  so a surprise upstream change can't silently alter the pipeline.
- **No secrets.** Nothing here needs API keys; the auto-provided `GITHUB_TOKEN` is enough.
- **Minute-savers.** `paths:` filters skip irrelevant pushes; `concurrency` cancels
  superseded runs; Linux-only avoids the ×2/×10 Windows/macOS multipliers.

---

## 10. Extending the CI (recipes)

Common changes, each small:

**Add a new environment to the test matrix** — three edits keep it in sync:

```yaml
# .github/workflows/test-environments.yml
matrix:
  env: [core, ml, dl, web, tools, tf, geo, ts, port]   # 1) add the short key
# 2) add a case arm mapping it to file/name/key:
#      port) file=09-portfolio.yml; name=py312-port; key=port ;;
# 3) add a "port": [...] entry to ENV_IMPORTS in scripts/verify-env.py
```

**Lock a new environment/template** — add its path to the `target:` matrix in
`update-lockfiles.yml` (e.g. `- environments/09-portfolio`).

**Add functional tests** — after the verify step in `test-environments.yml`, run your test
suite inside the built env:

```yaml
- name: Run unit tests
  run: conda run --no-capture-output -n "${{ steps.resolve.outputs.name }}" pytest -q
```

**Add a security gate** — drop the local script straight into a job step:

```yaml
- name: CVE scan
  run: bash python/3.12/scripts/audit-env.sh 04-web
```

**Change the schedule** — edit the `cron:` expression (e.g. `"0 6 * * *"` for daily 06:00 UTC).

---

## 11. Troubleshooting common CI failures

| Symptom in the log | Cause | Fix |
|--------------------|-------|-----|
| `channels must be exactly [conda-forge]` | a YAML lists `defaults`/`nvidia` | make `channels:` exactly `[conda-forge]` |
| `no python= pin found` | environment has no `python=` line | add e.g. `- python=3.12.*` |
| `missing name:` / `missing or empty dependencies:` | malformed YAML | add the missing key |
| `!! <pkg> IMPORT FAILED` in verify | package didn't install, or a native lib is missing | check the name; for `cv2` ensure `libgl1` is present (CI installs it) |
| `conda/pip clash detected` | same package from both conda and pip | remove the duplicate; prefer the conda-forge one |
| `conda-lock failed for <name>` | a target can't be resolved for that platform | see the notes in `update-lockfiles.yml` (e.g. `sagemaker` is pinned; TF has no win-64 build) |
| checkout fails inside the container | Miniforge image lacks `git` | the "Install system deps" step installs it — keep that step |

When in doubt, reproduce locally with the [§8](#8-reproduce-the-ci-locally-dont-wait-on-github)
commands; the container and steps are identical, so a local green means a CI green.

---

## 12. Glossary

- **CI (Continuous Integration)** — automatically building and testing every change.
- **CD (Continuous Deployment)** — automatically shipping what passes CI (not done here;
  the repo's "ship" step is the container images in [`docker/`](../docker/)).
- **workflow / job / step** — a pipeline file / a unit that runs on one VM / one command.
- **runner** — the throwaway VM a job runs on (`ubuntu-latest`).
- **action** — a reusable, versioned step referenced with `uses:`.
- **matrix** — running one job many times over a list of inputs, in parallel.
- **container** — running a job inside a Docker image (here `condaforge/miniforge3`).
- **artifact** — a file uploaded by a run for download or hand-off between jobs.
- **`workflow_dispatch`** — the manual **Run workflow** trigger.
- **cron** — the timer syntax for `schedule:` (`min hour dom month dow`).
- **`GITHUB_TOKEN`** — the auto-generated, scoped credential a run uses.
- **`GITHUB_OUTPUT`** — the file a step writes to pass values to later steps.
- **branch protection / required check** — a rule that blocks merging until named
  workflows pass.

---

## 13. Mastery checklist

You've mastered this repo's CI when you can, without looking:

- [ ] Name the **three** workflows and say, in one line each, what they guarantee.
- [ ] Explain the difference between a **gate** (`validate`, `test-environments`) and a
      **maintainer** (`update-lockfiles`).
- [ ] Read `on:` + `paths:` and predict whether a given commit triggers a workflow.
- [ ] Explain what a **matrix** does and why `fail-fast: false` is used.
- [ ] Say why the job runs **inside a container** and why CI is **Linux-only**.
- [ ] List `validate`'s four rules and fix a YAML that breaks one.
- [ ] Explain the **conda/pip clash** check and why it matters.
- [ ] Read the `cron: "0 6 * * 1"` schedule and change it.
- [ ] Explain why only `update-lockfiles` needs `permissions: write`.
- [ ] Launch a workflow by hand from the **Actions** tab and read its logs.
- [ ] Reproduce each gate **locally** before pushing.

---

**See also:** [user-workflows.md](user-workflows.md) (the commands you run) ·
[lockfiles — explained](../python/3.12/lockfiles/LOCKFILES-EXPLAINED.md) ·
[compatibility](compatibility.md) (why CI is Linux-only) ·
[architecture](architecture.md) · the raw files in [`.github/workflows/`](../.github/workflows/).
