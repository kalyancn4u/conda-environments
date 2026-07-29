# How the lockfiles are generated

This folder documents **how** the `linux-64` / `win-64` / `osx-arm64` lockfiles under
`python/3.12/lockfiles/<platform>/` are produced, and where to find the run logs.

Lockfiles are **explicit** [`conda-lock`](https://github.com/conda/conda-lock) files: a
frozen, hash-pinned list of exact package URLs that rebuilds an environment identically
on a given OS. They are generated from the loosely-pinned `environments/*.yml` — see
[`docs/upgrade-strategy.md`](../../../../docs/upgrade-strategy.md) for the intent-vs-lock model.

---

## Method 1 — GitHub Actions ✅ (recommended; no local install)

Runs Miniforge + `mamba` + `conda-lock` on GitHub's Linux runners. Nothing is installed
on your machine.

1. Go to the repo on GitHub → **Actions** tab → **update-lockfiles** workflow.
2. Click **Run workflow**. The `platforms` input defaults to **`linux-64`** (fast,
   quick-reference). Enter `linux-64 win-64 osx-arm64` to lock all platforms.
3. When it finishes:
   - **Lockfiles** arrive as a **pull request** (`chore/update-lockfiles`) that adds the
     files under `python/3.12/lockfiles/<platform>/`. Review the version deltas and merge.
   - They are **also** attached to the run as downloadable **artifacts**
     (`lockfiles-<env>`), a fallback if PR creation is restricted by org settings.
   - **Logs**: open the run → each `conda-lock <env>` job shows the full solver output.
     Download the whole log via **⋯ → Download log archive**, or with the CLI:
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
  cd python/3.12
  for e in 01-core 02-ml 03-deep-learning 04-web 05-tools 06-tensorflow 07-geospatial 08-timeseries; do
    echo "=== $e ==="
    mkdir -p lockfiles/linux-64
    conda-lock lock --file environments/$e.yml --platform linux-64 --kind explicit \
      && mv -f conda-linux-64.lock lockfiles/linux-64/$e.conda.lock
  done
' | tee python/3.12/lockfiles/generation/linux-64-conda-lock.log
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

cd /mnt/c/Users/<you>/.../conda-environments/python/3.12
for e in 01-core 02-ml 03-deep-learning 04-web 05-tools 06-tensorflow 07-geospatial 08-timeseries; do
  conda-lock lock --file environments/$e.yml --platform linux-64 --kind explicit \
    && mv -f conda-linux-64.lock lockfiles/linux-64/$e.conda.lock
done
```

---

## Using a lockfile

```bash
# Rebuild an environment EXACTLY from its linux-64 lock:
conda create --name py312-core --file python/3.12/lockfiles/linux-64/01-core.conda.lock
```

## Logs in this folder

Run logs are captured here as `*-conda-lock.log` when generated via Method 2/3, or
downloaded from the Actions run for Method 1. They are reference material — the
authoritative artifacts are the lockfiles themselves under `../<platform>/`.
