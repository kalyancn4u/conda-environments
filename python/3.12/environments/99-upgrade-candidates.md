# Upgrade Candidates & Migration Report

This report is the analysis behind the modular environments in this directory. It
categorizes packages found in the **source `base` environment** (~640 conda + ~20
pip packages) and recommends what to keep, upgrade, replace, or remove.

> **Legend**
> ✅ Safe upgrade · ⚠️ Compatibility-sensitive · 🔁 Replace · 🗑️ Remove · ☠️ End-of-life / broken

---

## 1. Safe upgrades ✅

These just track the latest conda-forge build; no code changes expected. They are
already reflected (unpinned) in the modular environments.

| Package | Notes |
|---|---|
| numpy, pandas, scipy | Core numerics; let conda-forge resolve. **Do not** mix conda + pip copies (see §5). |
| scikit-learn, statsmodels | Stable APIs. |
| jupyterlab, notebook, ipykernel, ipywidgets | Move to JupyterLab 4.x / Notebook 7.x. |
| matplotlib, seaborn, plotly | `matplotlib-base` is enough for headless; full `matplotlib` pulls Qt. |
| requests, httpx, beautifulsoup4, lxml | Networking/parsing; current. |
| xgboost, lightgbm, catboost | CPU builds; see §2 for the GPU/CUDA caveat. |
| pydantic (v2) | Already v2 in source; keep. |

---

## 2. Compatibility-sensitive upgrades ⚠️

| Package | Concern | Recommendation |
|---|---|---|
| **pytorch / torchvision / torchaudio** | Source env had only CPU `libtorch`, **no Python bindings**. | Install real `pytorch` from conda-forge (CPU by default). GPU: match CUDA to the build — see `docs/compatibility.md`. |
| **tensorflow** | conda-forge has **no win-64 build**. Source pinned CPU `2.20`. | Linux/macOS: conda-forge. **Windows: `pip install tensorflow`.** Isolated in `06-tensorflow.yml`. |
| **xgboost / lightgbm / arrow / pyarrow (`cuda129` builds)** | Source pulled CUDA-linked builds into `base`, making it non-portable. | Use plain CPU builds in the YAMLs; opt into CUDA explicitly per `docs/compatibility.md`. |
| **keras** | Keras 3 is multi-backend; `tf-keras` is the legacy shim. | Use Keras 3; only add `tf-keras` if a dependency demands the 2.x API. |
| **spacy / thinc / transformers** | Model/tokenizer versions are tightly coupled. | Keep them in one environment (`03-deep-learning`) so the solver pins them together. |
| **airflow (3.x) + providers** | Huge dependency tree; conflicts easily with data libs. | Moved out of core into `templates/mlops.yml`; run it in a dedicated env/container. |

---

## 3. Replace with a modern equivalent 🔁

| Legacy | Replace with | Why |
|---|---|---|
| `bs4` (PyPI shim) | `beautifulsoup4` | `bs4` is an empty placeholder that just depends on the real package. |
| `docopt` | `typer` / `click` / `argparse` | Unmaintained; modern CLIs are typed and testable. |
| `keras-preprocessing` | `keras` / `tf.data` | Folded into Keras; standalone package is dead. |
| `tensorflow-estimator` | `keras` | Estimator API deprecated by TensorFlow. |
| `gensim` (word2vec) | `sentence-transformers` | For most embedding tasks, transformer embeddings outperform. Keep gensim only for classic LDA/word2vec. |
| `pip-search` / `pipreqs` / `yarg` | PyPI website / explicit deps | Fragile HTML-scraping tools; not reproducible. |

---

## 4. Remove — not needed on Python 3.12 🗑️

Installing these on 3.12 is at best redundant and at worst **actively breaks imports**.

| Package | Reason |
|---|---|
| `dataclasses` | Stdlib since 3.7. The backport shadows the stdlib module. |
| `typing` (PyPI backport) | Stdlib. The backport can mask `typing` features. |
| `backports.strenum` | `enum.StrEnum` is stdlib since 3.11. |
| `backcall`, `pickleshare` | Legacy IPython shims no longer imported. |
| `entrypoints` | Superseded by `importlib.metadata`. |
| `tensorboard-plugin-wit` | Unmaintained TensorBoard plugin. |
| `m2w64-*`, `mingw-w64-*`, `msys2-*`, `binutils_win-64` | Build toolchains — never belong as environment dependencies. |
| `cuda-*`, `libcublas*`, `libcusolver*`, `libcusparse*` | CUDA runtime pulled into `base`; install per-project when GPU is needed. |

---

## 5. Broken / end-of-life in the source env ☠️

| Package | Problem | Action |
|---|---|---|
| **`transformers==2.1.1`** | 2019-era release, incompatible with the env's own `tokenizers 0.23` / `huggingface_hub 0.34`. | Replace with modern `transformers` (4.x) in `03-deep-learning`. |
| **conda `numpy-base=1.26.4` + pip `numpy==2.4.4`** | Two numpy installs from two package managers → ABI corruption. | Single numpy from conda-forge only. |
| **conda `matplotlib-base=3.11` + pip `matplotlib==3.10.9`** | Duplicate installs. | Single matplotlib from conda-forge only. |
| **pip `ipython==8.12.3`** | Pinned to the last 3.8-compatible line for no reason on 3.12. | Let conda-forge resolve IPython. |
| `datasets==2.2.1`, `streamlit==1.8.0`, `sagemaker==2.75.1`, `wandb==0.27.2` | Significantly behind. | Upgrade; SageMaker/wandb belong in `templates/mlops.yml`. |

---

## 6. Golden rule extracted from this analysis

> **Never mix `conda` and `pip` for the same package.** The single biggest source of
> breakage in the source environment was PyPI packages (numpy, matplotlib, pandas)
> installed on top of their conda-forge equivalents. In these environments, `pip` is
> reserved strictly for packages that have **no** conda-forge distribution.
