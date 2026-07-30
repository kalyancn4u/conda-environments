# uv requirements (production / CI-CD)

Fully-pinned, **PyPI-only** `requirements.txt` files — one per environment and template —
for installing with [uv](https://github.com/astral-sh/uv) (or pip) in production and CI/CD.

- `<name>.in`  — loose **intent** (top-level PyPI package names).
- `<name>.txt` — the **pinned lock**, produced by `uv pip compile` (Python 3.12, linux).

```bash
# create an isolated environment, then install a pinned set into it
python -m venv .venv && source .venv/bin/activate    # or: uv venv
uv pip install -r 04-web.txt                          # or: pip install -r 04-web.txt

# in a container you can skip the venv and install into the system Python:
#   uv pip install --system -r 04-web.txt

# regenerate a lock from its intent (after editing the .in)
uv pip compile 04-web.in -o 04-web.txt --python-version 3.12 --python-platform linux
```

> New to virtual environments? [`docs/conda-vs-uv.md`](../../../../docs/conda-vs-uv.md)
> explains `venv` vs. conda environments from scratch.

## conda lockfiles vs. these

| | conda lockfiles (`../<platform>/`) | these `requirements.txt` |
|---|---|---|
| Scope | Python **+ native libs** (GDAL, CUDA, …) | **PyPI wheels only** |
| Stage | development / research | **production / CD** |
| Tool | `conda` / `mamba` | `uv` / `pip` |

See [`docs/conda-vs-uv.md`](../../../../docs/conda-vs-uv.md) for the full explanation.

## Caveats

Some environments rely on conda's native-library support and **do not translate cleanly
to PyPI** — their `.txt` is provided for reference; prefer conda in production:

- **`07-geospatial`** — GDAL/rasterio/fiona need system GDAL/GEOS/PROJ to build.
- **`08-timeseries`** — Prophet compiles Stan via `cmdstan` (native).
- **`06-tensorflow`** and the **`all-in-one-*`** files (which include the geospatial stack).

## Names

`requirements.txt` uses **PyPI** names, which often differ from conda-forge names
(`torch` vs `pytorch`, `opencv-python-headless` vs `opencv`, `feature-engine` vs
`feature_engine`, `redis` vs `redis-py`). See `docs/package-selection.md`.
