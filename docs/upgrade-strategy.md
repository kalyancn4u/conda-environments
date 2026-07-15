# Upgrade Strategy

How to move versions forward without breaking environments — and how the two-layer
(intent vs. lock) model makes that safe.

## Principles

- **Unpinned YAMLs float; lockfiles freeze.** Because the `*.yml` files pin only
  `python`, a fresh solve naturally picks up compatible upgrades. Lockfiles capture a
  known-good resolution for reproducible rebuilds until you choose to move.
- **Upgrade in small, reviewable steps.** Bump one environment at a time; keep intent
  changes and lockfile refreshes in separate PRs.
- **Prove it before merging.** CI creates each environment and runs the import
  verifier. A green `test-environments` run is the bar.

## Routine upgrade workflow

```bash
# 1. Re-solve the environment from intent (picks up newer compatible packages)
./python/3.12/scripts/update-env.sh 01-core     # uses --prune

# 2. Smoke-test imports
conda activate py312-core
python python/3.12/scripts/verify-env.py --env core

# 3. See what actually moved (optional)
./python/3.12/scripts/compare-envs.sh --outdated py312-core

# 4. Refresh the lockfiles (or let the update-lockfiles workflow do it)
#    conda-lock -f python/3.12/environments/01-core.yml -p linux-64 -p win-64 -p osx-arm64
```

## Classifying an upgrade

Use the categories from
[`99-upgrade-candidates.md`](../python/3.12/environments/99-upgrade-candidates.md):

| Category | Handling |
|---|---|
| ✅ Safe | Re-solve; merge on green CI. |
| ⚠️ Compatibility-sensitive | Read release notes; test the specific workflow (e.g. a torch/transformers pin move); consider a temporary bound. |
| 🔁 Replace | Swap the package, update imports, note it in CHANGELOG. |
| 🗑️ Remove | Delete from the YAML; `--prune` on update removes it from envs. |
| ☠️ End-of-life | Replace urgently; never carry forward broken pins like `transformers==2.1.1`. |

## When (and how) to pin

Add a version constraint **only** for a concrete, documented reason:

```yaml
  # Pin: 1.5.x changed the CSV engine and breaks our loaders (tracked in #123).
  - somelib=1.4.*
```

Prefer the **loosest** bound that solves the problem (`>=`, `<next-major`, or a
`1.4.*` series) over an exact `==` pin. Revisit pins periodically — a stale pin is
technical debt. Never pin build strings in the human YAMLs; that is the lockfile's job.

## Adding a new Python version

1. `cp -r python/3.12 python/3.13`
2. Change `python=3.12.*` → `python=3.13.*` in every YAML.
3. Re-solve each environment; fix any packages that lack 3.13 builds yet (they usually
   arrive on conda-forge within weeks of a release).
4. Regenerate lockfiles for the new version.
5. Keep 3.12 available until 3.13 is proven — the directory structure supports both.

## Deprecation policy

When a package becomes unmaintained or is superseded:

1. Move it to `98-legacy.yml` (commented, with the reason and its replacement).
2. Record the migration in [`99-upgrade-candidates.md`](../python/3.12/environments/99-upgrade-candidates.md).
3. Note it in `CHANGELOG.md`.
