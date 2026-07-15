# Architecture

This document explains *why* the repository is shaped the way it is. The goal is a
structure that stays maintainable for years and across multiple Python versions.

## Design goals

1. **Modularity** — each environment addresses one concern. Small environments
   solve faster, conflict less, and are easier to reason about than one giant env.
2. **Reproducibility** — human-readable intent (`*.yml`) is separated from exact,
   machine-generated state (lockfiles).
3. **Maintainability** — minimal pinning and clear comments so upgrades are cheap.
4. **Portability** — CPU-only definitions solve identically on Linux, Windows, and
   Apple Silicon; hardware-specific concerns are documented, not hard-coded.

## Directory layout & the version prefix

```text
python/
└── 3.12/
    ├── environments/   # modular definitions (the source of truth for intent)
    ├── templates/      # opinionated starting points to fork per project
    ├── scripts/        # create/update/export/clean/compare/verify helpers
    └── lockfiles/      # generated, per-platform, exact-rebuild artifacts
```

The `python/<version>/` prefix is the key structural decision. Everything that is
version-specific lives under it, so introducing Python 3.13 is a **copy + re-solve**:

```bash
cp -r python/3.12 python/3.13
# bump `python=3.12.*` -> `python=3.13.*` in each YAML, then re-solve
```

No shared/global files need to change, and multiple Python versions coexist without
interfering. Cross-cutting documentation (this `docs/` tree) stays version-agnostic
and references version-specific details where needed.

## The environment matrix

| Env | Concern | Why it is separate |
|-----|---------|--------------------|
| `01-core` | Scientific Python daily driver | The 80–90% case; kept small and stable |
| `02-ml` | Classical ML | Boosting/tuning trees are heavy and evolve independently |
| `03-deep-learning` | PyTorch + Hugging Face | Large binary deps; framework-specific |
| `06-tensorflow` | TensorFlow + Keras | **Isolated from PyTorch** to avoid protobuf/abseil/numpy contention |
| `04-web` | Web APIs & data apps | Server/runtime concerns, different release cadence |
| `05-tools` | Dev tooling | A "toolbox" independent of any project runtime |
| `98-legacy` | Deprecated packages | Reference/documentation only |

Templates (`minimal`, `data-science`, `mlops`, `llm`) are **compositions** for common
personas — convenience supersets you fork and trim, not additional modules to maintain.

### Why split TensorFlow and PyTorch?

Both frameworks pin low-level libraries aggressively (`protobuf`, `abseil`, `numpy`,
CUDA runtimes). Co-installing them frequently produces an unsolvable environment or a
silently downgraded one. Splitting them means each solves cleanly and upgrades on its
own schedule. Few real projects need both frameworks in a single interpreter; those
that do can compose the two YAMLs deliberately and accept the tighter constraints.

### Why Airflow/SageMaker live in a template, not a module

Apache Airflow brings a very large, opinionated dependency tree (schedulers,
providers, web server) and is POSIX-oriented. Bundling it into `04-web` would make an
otherwise fast environment slow and fragile. It belongs in a dedicated environment or
container — hence `templates/mlops.yml`.

## Intent vs. lock: the two-layer model

```text
environments/01-core.yml   (INTENT: what we want, minimally pinned)
        │  conda-lock / conda env export
        ▼
lockfiles/<platform>/01-core.lock   (STATE: exact versions+builds+hashes)
```

- **YAML** is what humans edit and review. It expresses intent with as few pins as
  possible so the solver can pick compatible, up-to-date versions.
- **Lockfiles** are generated per platform for byte-for-byte reproducible rebuilds
  (CI, production). They are never hand-edited. See
  [upgrade-strategy.md](upgrade-strategy.md) and the `update-lockfiles` workflow.

This separation is what lets us have *both* "avoid unnecessary pinning" *and*
"fully reproducible" without contradiction.
