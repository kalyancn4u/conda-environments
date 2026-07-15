# Compatibility: Channels, Platforms, and CUDA

## conda-forge vs. defaults

This repository standardizes on a **single channel: `conda-forge`**.

- **Consistency.** conda-forge builds packages against a coherent set of dependencies.
  Mixing `defaults` (Anaconda's channel) with `conda-forge` mixes two build matrices
  and is a classic source of unsolvable or subtly broken environments.
- **Coverage & freshness.** conda-forge is community-maintained, broad, and fast-moving.
- **Licensing/ToS.** Using `conda-forge` avoids the Anaconda Terms-of-Service
  considerations that can apply to the `defaults` channel in commercial settings.

Configure it once, globally, with **strict** priority:

```bash
conda config --add channels conda-forge
conda config --set channel_priority strict
```

Each environment file also declares `channels: [conda-forge]` explicitly, so a
correct solve does not depend on the user's global config. **Do not** add `defaults`,
`nvidia`, or the raw `repo.anaconda.com` URLs back into the YAMLs.

> **Solver tip:** use `mamba`, or `conda` ≥ 23.10 which ships the fast libmamba
> solver by default. The scripts auto-detect `mamba`.

## Platform support matrix

Environments are authored for three primary platforms. Not every package builds for
every platform — the notable gaps are called out here.

| Package / env | linux-64 | win-64 | osx-arm64 | Note |
|---|:---:|:---:|:---:|---|
| `01-core`, `02-ml`, `04-web`, `05-tools` | ✅ | ✅ | ✅ | Fully portable |
| `03-deep-learning` (PyTorch) | ✅ | ✅ | ✅ | CPU builds on all three |
| `06-tensorflow` | ✅ | ❌ | ✅ | **No conda-forge win-64 build** — see below |
| `gunicorn` (in `04-web`) | ✅ | ❌ | ✅ | POSIX-only server; use `uvicorn`/`waitress` on Windows |
| `apache-airflow` (template) | ✅ | ⚠️ | ✅ | Use WSL2/Docker on Windows |

### TensorFlow on Windows

conda-forge does **not** publish a `win-64` build of `tensorflow`. On Windows, create
the environment without the conda `tensorflow` package and install it via pip:

```bash
conda create -n py312-tf python=3.12 pip
conda activate py312-tf
pip install "tensorflow>=2.19"     # official Windows wheels come from PyPI
```

On Linux and Apple Silicon, `06-tensorflow.yml` works as-is via conda-forge.

## CUDA installation strategy

The environment YAMLs are **CPU-only on purpose**. Baking CUDA into the definitions
was one of the defects of the source `base` environment: it made the env huge,
non-portable, and impossible to reproduce on machines without a matching GPU/driver.

Instead, opt into GPU **per project**, on top of a working CPU environment.

### PyTorch with CUDA

conda-forge exposes CUDA-enabled builds selected via a virtual package. On a machine
with a suitable NVIDIA driver:

```bash
# In (or when creating) the deep-learning environment, request a CUDA build:
conda install -n py312-dl "pytorch=*=cuda*" pytorch-cuda -c conda-forge
```

Match the CUDA version to your **driver** (the driver must be ≥ the toolkit version).
Verify:

```python
import torch; print(torch.__version__, torch.cuda.is_available())
```

### TensorFlow with CUDA

On Linux, the pip TensorFlow package bundles the needed CUDA libraries:

```bash
pip install "tensorflow[and-cuda]"
```

### Gradient boosting (XGBoost / LightGBM) with GPU

Install the GPU build explicitly when needed, e.g.:

```bash
conda install -n py312-ml "py-xgboost-gpu"   # or lightgbm's GPU build
```

### Golden rules for GPU

1. Keep GPU packages **out of the tracked YAMLs** — they are environment-local.
2. Pin CUDA to your **driver**, not the other way around.
3. Record GPU steps in the *project's* README, not this shared repository.
