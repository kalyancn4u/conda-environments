# Lockfiles

Generated, per-platform, **exact-rebuild** artifacts. These freeze a known-good
resolution of each environment (versions + builds + hashes) so a rebuild is
byte-for-byte reproducible — independent of when or where it runs.

```text
lockfiles/
├── linux-64/
├── win-64/
└── osx-arm64/
```

## Rules

- **Do not hand-edit.** Lockfiles are machine-generated. Edit the `*.yml` intent files
  instead, then regenerate.
- **Committed intentionally.** Unlike environment exports (which are gitignored),
  lockfiles are tracked so consumers get reproducible builds.
- **One PR at a time.** Keep intent changes and lockfile refreshes in separate PRs so
  reviews stay legible.

## Generating locally

Uses [`conda-lock`](https://github.com/conda/conda-lock):

```bash
pip install conda-lock   # or: conda install -c conda-forge conda-lock

conda-lock lock \
  --file ../environments/01-core.yml \
  --platform linux-64 --platform win-64 --platform osx-arm64
```

In CI this is handled by the [`update-lockfiles`](../../../.github/workflows/update-lockfiles.yml)
workflow. See [docs/upgrade-strategy.md](../../../docs/upgrade-strategy.md) for how
lockfiles fit the intent-vs-state model.
