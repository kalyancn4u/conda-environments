# Docker images

<sub>📍 [conda-environments](../README.md) › **docker**</sub>

Reference Dockerfiles that turn this repo's environment definitions into container
images. Two images, mirroring the two install paths in
[`docs/conda-vs-uv.md`](../docs/conda-vs-uv.md):

| File | Base | Installs | Use it for |
|------|------|----------|------------|
| [`Dockerfile.uv`](Dockerfile.uv) | `python:<ver>-slim` | a pinned `requirements.txt` with **uv** (PyPI only) | pure-Python **services** shipped to production/CD — small, fast |
| [`Dockerfile.conda`](Dockerfile.conda) | `mambaorg/micromamba` | a conda **environment/template** `.yml` | stacks needing **native libs** — GDAL, Prophet/cmdstan, MKL, OpenCV |

> **Which one?** Same rule as everywhere in this repo: *pure-Python → uv; native
> system libraries → conda.* See the [decision guide](../docs/conda-vs-uv.md#6-when-to-use-which--the-decision-guide).

**Both Dockerfiles expect the build context to be the repository root**, so the
`python/<ver>/...` files are in scope. Run the `docker build` commands from the repo
root (not from inside `docker/`).

---

## `Dockerfile.uv` — slim PyPI service

Build args: `PYTHON_VERSION` (base image tag), `PYVER` (which `python/<ver>` tree),
`REQUIREMENTS` (the requirements stem under `lockfiles/requirements/`).

```bash
# from the repo root — build the web service image
docker build -f docker/Dockerfile.uv \
  --build-arg PYVER=3.12 --build-arg REQUIREMENTS=04-web \
  -t conda-environments/web:uv .

# run it (override CMD with your real entrypoint)
docker run --rm -p 8000:8000 conda-environments/web:uv \
  uvicorn app:app --host 0.0.0.0 --port 8000
```

It is a two-stage build: the first stage resolves and installs the wheels, the
runtime stage copies only the installed packages and runs as a non-root user.

> ⚠️ The `requirements.txt` files are compiled for **linux + CPython 3.12** (the
> deploy target). That matches these Linux images. For a different Python, pass a
> matching `PYTHON_VERSION`/`PYVER` **and** use a requirements file compiled for it
> (see [`docs/conda-vs-uv.md`](../docs/conda-vs-uv.md#are-the-requirementstxt-os-specific-yes)).

## `Dockerfile.conda` — reproducible scientific image

Build args: `PYVER` (tree), `KIND` (`environments` or `templates`), `ENVFILE`
(the file stem). The environment is installed into `base`, so it is **active by
default** — no activation step in your `docker run`.

```bash
# a modular environment
docker build -f docker/Dockerfile.conda \
  --build-arg PYVER=3.12 --build-arg KIND=environments --build-arg ENVFILE=07-geospatial \
  -t conda-environments/geo:conda .

# a template
docker build -f docker/Dockerfile.conda \
  --build-arg KIND=templates --build-arg ENVFILE=data-science \
  -t conda-environments/ds:conda .

docker run --rm conda-environments/geo:conda \
  python -c "import geopandas; print(geopandas.__version__)"
```

Notes:

- The image installs `libgl1`/`libglib2.0-0` so the OpenCV-based deep-learning
  stacks import headlessly (same as CI). Harmless for envs that don't use `cv2`.
- **TensorFlow** has no conda-forge win-64 build; on Linux images it's fine.
- The `.yml` captures **intent**, not exact versions. For a byte-for-byte
  reproducible image, generate a lockfile and install from it instead — see
  [lockfiles](../python/3.12/lockfiles/README.md).

## Reproducing locally without Docker

The `python/<ver>/scripts/` helpers cover the same ground on a workstation:
`micromamba-env.sh` (zero-install conda env), `setup-venv.sh` (venv + uv), and
`test-env.sh` (build + verify in the CI container). See
[`docs/workflows.md`](../docs/workflows.md).

## A minimal CI build check

Validate a Dockerfile without a full image pull/build using BuildKit's linter:

```bash
docker build --check -f docker/Dockerfile.uv \
  --build-arg REQUIREMENTS=04-web .
```
