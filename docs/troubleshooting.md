# Troubleshooting

Practical fixes for the failures you are most likely to hit.

## Solves are slow or hang

- Use **mamba** or ensure `conda` ≥ 23.10 (libmamba solver). The helper scripts
  auto-detect `mamba`.
- Confirm strict priority is set: `conda config --show channel_priority` → `strict`.

## `PackagesNotFoundError` / `Nothing provides ...`

Usually a channel or platform problem.

1. Check channel config — you want **only** conda-forge:
   ```bash
   conda config --show channels          # expect: conda-forge
   conda config --set channel_priority strict
   ```
2. Check the **platform matrix** in [compatibility.md](compatibility.md). Some
   packages have no build for your OS — most importantly **`tensorflow` has no
   conda-forge win-64 build** (install via pip on Windows), and `gunicorn` is
   POSIX-only.

## `UnsatisfiableError` (conflicting requirements)

- You are probably co-installing frameworks that pin low-level libs differently
  (e.g. TensorFlow + PyTorch). Keep them in **separate** environments — that is why
  `03-deep-learning` and `06-tensorflow` are split.
- Read the solver's conflict report from the bottom up; the last lines name the
  packages that cannot coexist.
- Temporarily loosen or remove any manual version pins and re-solve.

## Imports break after a `pip install`

The classic conda+pip ABI clash (the source `base` env had two numpys, two
matplotlibs). Rules:

- Install from **conda-forge first**; use `pip` only for packages with no conda-forge
  build.
- Never `pip install` a package that conda already provides (numpy, pandas,
  matplotlib, scipy, ...).
- To inspect what pip added on top of conda:
  ```bash
  conda list | grep '<pip>'
  ```
- If an env is corrupted this way, recreate it from the YAML rather than repairing.

## `playwright` / `selenium` can't find a browser

Playwright needs its browser binaries after the package installs:

```bash
python -m playwright install
```

Selenium needs a driver on `PATH` (or use Selenium Manager, bundled in recent
versions).

## Wrong Python or packages after activation

- Confirm the active env: `conda info --envs` (look for the `*`).
- `which python` / `Get-Command python` should point inside the env's directory.
- If a shell was open before `conda init`, restart it.

## Verifier reports an import failure

```bash
python python/3.12/scripts/verify-env.py --env core
```

A `!!  <pkg> IMPORT FAILED` line tells you exactly which package is broken. Re-create
the environment; if it persists, the package may lack a build for your platform
(check the matrix) or need OS-level libraries.

## Disk filling up

Conda caches build tarballs and index metadata. Reclaim space safely (caches only,
never your environments):

```bash
./python/3.12/scripts/clean-env.sh          # dry run
./python/3.12/scripts/clean-env.sh --yes    # actually clean
```

## Still stuck?

Open an issue with: your OS, `conda --version`, `conda config --show channels`, the
exact command, and the **full** error output (not just the last line).
