# Lockfiles

<sub>📍 [conda-environments](../../../README.md) › [Python 3.10](../README.md) › **lockfiles**</sub>

> ⏳ **Python 3.10 lockfiles are generated on demand** and are currently pending (all
> environments are [validated as ready](../README.md#-python-310-readiness)). The commands
> below show the pattern; the fully-locked reference set lives under
> [`python/3.12/lockfiles/`](../../3.12/lockfiles/).

Generated, per-platform, **exact-rebuild** artifacts. A lockfile freezes a known-good
resolution of one environment (exact versions + builds + `sha256` hashes) so a rebuild is
byte-for-byte reproducible — independent of when or where it runs. They are **explicit**
[`conda-lock`](https://github.com/conda/conda-lock) files generated from the
loosely-pinned `../environments/*.yml`.

```text
lockfiles/
├── linux-64/     ← exact conda recipes for Linux
├── win-64/       ← exact conda recipes for Windows
├── osx-arm64/    ← exact conda recipes for Apple-Silicon Macs
└── requirements/ ← PyPI-only requirements.txt (uv) for production / CI-CD
```

> **conda lockfiles** (`<platform>/`) reproduce the full *development* env (Python + native
> libs). **[`requirements/`](requirements/)** holds uv-compiled `requirements.txt` for
> *production* (PyPI wheels only). See [`docs/conda-vs-uv.md`](../../../docs/conda-vs-uv.md).

## Quick reference

```bash
# DEV — exact conda rebuild (linux-64, incl. native libs):
#   conda-only locks (01-core, 02-ml, 03-deep-learning, 04-web, 06-tensorflow,
#   07-geospatial, 08-timeseries, data-science, minimal):
conda create --name py310-core --file python/3.10/lockfiles/linux-64/01-core.conda.lock

#   locks that ALSO carry pip deps (05-tools, llm, mlops, all-in-one-pytorch,
#   all-in-one-tflow) must use conda-lock, which processes the `# pip …` lines
#   (plain `conda create --file` silently skips them):
conda-lock install --name py310-tools python/3.10/lockfiles/linux-64/05-tools.conda.lock

# PROD — pinned PyPI install with uv (Python 3.10 / linux target):
uv pip install -r python/3.10/lockfiles/requirements/04-web.txt
```

> **Why two DEV commands?** These are *explicit* conda locks. Any `pip:` dependency is
> recorded as a `# pip <pkg> @ …#sha256=` line, which `conda create --file` treats as a
> comment and ignores — so use **`conda-lock install`** for the five locks above to get the
> pip packages too. (Verified: installing `05-tools` this way yields a working `playwright`.)

> **Note on `mlops`:** its `sagemaker` dependency is pinned to `2.75.1` in the template —
> newer releases pull `torch → nvidia-cublas` CUDA wheels that conda-lock's pip solver
> can't resolve, and 2.75.1 is anyway the newest version that co-resolves with
> apache-airflow/boto3 here. Install it with `conda-lock install` (it carries pip deps).

> 🎓 **New to any of this?** Read [**LOCKFILES-EXPLAINED.md**](LOCKFILES-EXPLAINED.md)
> first — a from-first-principles explainer of what lockfiles are and what each generation
> step actually does. *This* file is the command reference; that one builds understanding.
> See also [`docs/upgrade-strategy.md`](../../../docs/upgrade-strategy.md) for the
> intent-vs-state model.

## Rules

- **Do not hand-edit.** Lockfiles are machine-generated. Edit the `*.yml` intent files
  instead, then regenerate.
- **Committed intentionally.** Unlike environment exports (which are gitignored),
  lockfiles are tracked so consumers get reproducible builds.
- **One PR at a time.** Keep intent changes and lockfile refreshes in separate PRs so
  reviews stay legible.

---

## Method 1 — GitHub Actions ✅ (recommended; no local install)

Runs Miniforge + `mamba` + `conda-lock` on GitHub's Linux runners. Nothing is installed
on your machine.

1. Repo on GitHub → **Actions** tab → **update-lockfiles** workflow.
2. **Run workflow**. The `platforms` input defaults to **`linux-64`** (fast, quick
   reference). Enter `linux-64 win-64 osx-arm64` to lock all platforms.
3. When it finishes:
   - **Lockfiles** arrive as a **pull request** (`chore/update-lockfiles`) adding the
     files under `lockfiles/<platform>/`. Review the version deltas and merge.
   - They are **also** attached to the run as downloadable **artifacts**
     (`lockfiles-<env>`), a fallback if PR creation is restricted by org settings.
   - **Logs**: open the run → each `conda-lock <env>` job shows the full solver output.
     Download via **⋯ → Download log archive**, or with the CLI:
     ```bash
     gh run view <run-id> --log > linux-64-conda-lock.log
     ```

> CLI trigger (needs `gh auth login`):
> ```bash
> gh workflow run update-lockfiles.yml -f platforms="linux-64"
> gh run watch   # follow it live
> ```

---

## Method 2 — Docker + Miniforge (canonical local)

Requires Docker Desktop running (after a Docker update, **reboot first** or the engine
won't start). Pulls the `condaforge/miniforge3` image (~500 MB) — nothing installed
outside the container.

```bash
docker run --rm -v "$(pwd)":/work -w /work condaforge/miniforge3:latest bash -c '
  set -e
  mamba install -y -n base conda-lock
  cd python/3.10
  for e in 01-core 02-ml 03-deep-learning 04-web 05-tools 06-tensorflow 07-geospatial 08-timeseries; do
    echo "=== $e ==="
    mkdir -p lockfiles/linux-64
    conda-lock lock --file environments/$e.yml --platform linux-64 --kind explicit \
      && mv -f conda-linux-64.lock lockfiles/linux-64/$e.conda.lock
  done
' | tee python/3.10/lockfiles/linux-64-conda-lock.log
```

---

## Method 3 — WSL + micromamba (small-footprint local, Windows)

If you want it local without a full Miniforge install, `micromamba` is a single ~30 MB
static binary. From WSL Ubuntu (paths via `/mnt/c/...`):

```bash
# one-time: fetch the micromamba binary (no system install)
curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xvj bin/micromamba
eval "$(./bin/micromamba shell hook -s bash)"
micromamba create -y -n lock -c conda-forge conda-lock
micromamba activate lock

cd /mnt/c/Users/<you>/.../conda-environments/python/3.10
for e in 01-core 02-ml 03-deep-learning 04-web 05-tools 06-tensorflow 07-geospatial 08-timeseries; do
  conda-lock lock --file environments/$e.yml --platform linux-64 --kind explicit \
    && mv -f conda-linux-64.lock lockfiles/linux-64/$e.conda.lock
done
```

---

## Using a lockfile

```bash
# Rebuild an environment EXACTLY from its linux-64 lock:
conda create --name py310-core --file python/3.10/lockfiles/linux-64/01-core.conda.lock
```

## Logs

Run logs can be saved here as `*-conda-lock.log` (Methods 2/3) or downloaded from the
Actions run (Method 1). They are reference material — the authoritative artifacts are the
lockfiles themselves under `<platform>/`. In CI, generation is handled by the
[`update-lockfiles`](../../../.github/workflows/update-lockfiles.yml) workflow.
