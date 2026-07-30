# Documentation

<sub>📍 [conda-environments](../README.md) › **docs**</sub>

Conceptual & reference documentation for **conda-environments**. New here? Read the guides
below **in order** — they take you from "never used conda" to "can maintain the whole
system." No prior knowledge assumed.

> Some entries live outside this folder (the file-by-file guide, the lockfile explainer,
> the per-directory READMEs). They're linked here so this page is the single map.

## ① Start — get productive
- [Beginner's guide](../python/3.12/GUIDE.md) — what every file & generated artifact is, in
  plain English, with a first-session walkthrough. **Start here.**
- [Environments & installers: conda / mamba / micromamba vs. venv + pip / uv](conda-vs-uv.md)
  — the tools themselves: virtual environments from scratch, which to use when,
  development vs. production, why CD uses uv, and how to keep uv from clobbering a conda env.

## ② Understand — the design
- [Architecture](architecture.md) — why the repo is split this way; the environment matrix.
- [Package selection](package-selection.md) — the philosophy behind every include/exclude,
  and the conda↔PyPI↔import name gotchas.
- [Compatibility](compatibility.md) — channels, per-platform support, and the CUDA/GPU strategy.

## ③ Reproduce — lockfiles & production
- [Lockfiles — explained](../python/3.12/lockfiles/LOCKFILES-EXPLAINED.md) — reproducibility
  from first principles.
- [Lockfiles — overview & generation methods](../python/3.12/lockfiles/README.md) —
  Actions / Docker / WSL commands, and how to *use* a lock.
- [uv requirements](../python/3.12/lockfiles/requirements/README.md) — pinned PyPI installs
  for production / CI-CD.

## ④ Maintain — keep it healthy
- [Upgrade strategy](upgrade-strategy.md) — moving versions forward safely.
- [Troubleshooting](troubleshooting.md) — when solves fail.
- [FAQ](faq.md) — quick answers.

---

**Audience note.** The three entry guides — the [beginner's guide](../python/3.12/GUIDE.md),
[conda-vs-uv](conda-vs-uv.md), and the [lockfile explainer](../python/3.12/lockfiles/LOCKFILES-EXPLAINED.md)
— are written **complete-novice → mastery**. The design docs in this folder
(architecture, package selection, compatibility, upgrade strategy) target
**intermediate-to-advanced** readers; the learning path is the bridge into them.

**Elsewhere in the repo:** [project overview](../README.md) ·
[Python 3.12 index](../python/3.12/README.md) · [CHANGELOG](../CHANGELOG.md) ·
[CONTRIBUTING](../CONTRIBUTING.md)
