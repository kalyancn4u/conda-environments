# FAQ

### Why multiple environments instead of one big one?

Small, single-purpose environments solve faster, conflict far less, and are easier to
reason about and reproduce. One monolithic env — like the `base` this repo was
distilled from — eventually becomes unsolvable. See
[architecture.md](architecture.md).

### Should I install these into `base`?

**No.** Keep `base` minimal (just conda/mamba). Create named environments from the
YAMLs. Polluting `base` is exactly the anti-pattern this repository exists to fix.

### conda or mamba?

Either. `mamba` (or `conda` ≥ 23.10 with the libmamba solver) is dramatically faster.
The scripts auto-detect `mamba` and fall back to `conda`.

### Why conda-forge only? Can I add `defaults`?

Please don't. Mixing channels mixes incompatible build matrices and causes subtle
breakage; `conda-forge`-only also sidesteps Anaconda `defaults` ToS concerns. See
[compatibility.md](compatibility.md).

### Why is almost nothing version-pinned?

So upgrades stay cheap and the solver can pick compatible, current builds. Exact
reproducibility comes from **lockfiles**, not from pinning the human-readable YAMLs.
Pin only when technically justified — and comment why.

### How do I get GPU/CUDA support?

Install a CUDA build on top of the CPU environment, per project. Full instructions
(PyTorch, TensorFlow, XGBoost/LightGBM) are in
[compatibility.md](compatibility.md#cuda-installation-strategy).

### Can I run TensorFlow and PyTorch together?

Not recommended — they pin low-level libraries in conflicting ways. They are split
into `06-tensorflow.yml` and `03-deep-learning.yml` on purpose. If you truly need
both, compose the two files and expect tighter constraints.

### Why doesn't `06-tensorflow.yml` work on my Windows machine?

conda-forge has no `win-64` build of `tensorflow`. Install it via pip on Windows
(`pip install "tensorflow>=2.19"`). Details in
[compatibility.md](compatibility.md#tensorflow-on-windows).

### How do I reproduce an environment exactly?

Use the lockfile for your platform under `python/3.12/lockfiles/<platform>/`, or
export a snapshot with `scripts/export-env.sh`. YAML captures *intent*; lockfiles
capture *exact state*.

### Can I mix `pip` packages in?

Only for packages with **no** conda-forge build (e.g. `tiktoken`, `sagemaker`), added
under a `pip:` block with a comment. Never `pip install` something conda already
provides — that ABI clash was the top defect in the source environment.

### How do I add support for a new Python version?

Copy `python/3.12/` to `python/3.13/`, bump the `python=` pin, and re-solve. Nothing
else needs to change. See [upgrade-strategy.md](upgrade-strategy.md).

### What is `98-legacy.yml` for?

Documentation. It records deprecated/removed packages and their modern replacements.
It is intentionally almost entirely commented out — not a working environment.
