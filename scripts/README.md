# uv-to-conda

<sub>📍 [conda-environments](../README.md) › **scripts** · Learning guide:
[docs/uv-to-conda.md](../docs/uv-to-conda.md)</sub>

Convert a pip `requirements.txt` into a Conda `environment.yml`, resolving any
**unpinned** packages with [`uv`](https://github.com/astral-sh/uv) — the extremely
fast Python resolver — while copying **pinned** versions through untouched.

> **New to this?** This page is the **reference** (every flag, exit codes, internals).
> For a gentle, complete-novice → mastery walkthrough — the problem it solves, the
> pip-vs-conda mental model, the two strategies explained with a story, and a
> step-by-step first run — read **[docs/uv-to-conda.md](../docs/uv-to-conda.md)** first.

This is a shared, repo-wide utility for the
[`conda-environments`](../README.md) project. It lives in `scripts/` alongside the
other cross-cutting tooling, and complements the per-version helpers under
`python/3.10/scripts` and `python/3.12/scripts`.

```
scripts/
├── uv-to-conda.py            # the tool
├── README.md                 # this file
└── examples/
    ├── requirements.latest.txt   # sample input
    ├── requirements.stable.txt   # sample input
    ├── environment.latest.yml    # representative output (latest strategy)
    └── environment.stable.yml    # representative output (stable strategy)
```

> **Naming note.** File names follow this repo's conventions: kebab-case scripts
> (`uv-to-conda.py`, like `verify-env.py`) and dot-separated variants
> (`environment.stable.yml`, like `Dockerfile.conda` and `*.conda.lock`).

---

## Why

Production environments demand **stability**, but `requirements.txt` files often
leave packages unpinned. This tool lets you:

- Keep the exact pins you care about (`numpy==1.26.0`) verbatim.
- Let `uv` resolve everything else — either to the **latest** compatible versions,
  or to conservative, **battle-tested** versions for production.
- Emit a clean, Conda-native `environment.yml` (with a `pip:` escape hatch for
  PyPI-only packages), ready for `conda env create`.

---

## Prerequisites

- **Python 3.8+** (standard library only — no third-party Python deps).
- **`uv`** on your `PATH`, but only if your input has unpinned packages:

  ```bash
  pip install uv
  ```

  A pinned-only `requirements.txt` is converted without invoking `uv` at all.

---

## Usage

```bash
# Default: latest strategy
python scripts/uv-to-conda.py -i requirements.txt -o environment.yml -n myenv

# Stable strategy (production-safe)
python scripts/uv-to-conda.py -i requirements.txt -o environment.yml -n prod -s stable
```

Then create the environment:

```bash
conda env create -f environment.yml
```

### CLI options

| Flag | Default | Description |
| :--- | :--- | :--- |
| `-i, --input` | `requirements.txt` | Input requirements file. |
| `-o, --output` | `environment.yml` | Output Conda environment file. |
| `-n, --name` | `myenv` | Conda environment name. |
| `-p, --python` | `3.12` | Target Python version. |
| `-c, --channels` | `conda-forge` | Comma-separated Conda channels. |
| `-s, --strategy` | `latest` | `latest` or `stable` (see below). |
| `--exclude-days` | `90` | For `stable`: ignore releases newer than N days. |
| `--system-certs` | off | Pass `--system-certs` to uv (trust the OS cert store; for TLS-intercepting proxies). |
| `-m, --mapping` | — | JSON file of PyPI→Conda name overrides. |
| `-v, --verbose` | off | Detailed logging to stderr. |

---

## Strategies

### `latest` (default)

Resolves unpinned packages to the **newest** compatible versions. Under the hood:

```bash
uv pip compile <in> --python-version 3.12 -o <out>
```

Use it for development, quick prototypes, and staying current.

### `stable`

Resolves unpinned packages to **battle-tested** versions: the newest stable
release that has had time to prove itself in the wild. Under the hood:

```bash
uv pip compile <in> \
    --exclude-newer <YYYY-MM-DD> \ # only releases at least <window> days old
    --prerelease disallow \        # no alpha / beta / RC
    --python-version 3.12 -o <out>
```

Use it when you want to avoid the "latest and greatest" risk in production and
prefer versions that have been available long enough to shake out regressions.

> **Why not `--resolution=lowest`?** An earlier draft of this strategy used
> `--resolution=lowest` to get the "oldest compatible" versions. In practice that
> is a trap for *unpinned* packages (this tool's whole input): "lowest" means the
> oldest version **ever published**, so `scikit-learn` resolves to `0.9` (circa
> 2011), which no longer builds — the opposite of production-ready. uv itself warns
> against bare `lowest` on unpinned direct dependencies. The `stable` strategy
> therefore uses uv's default (highest) resolution but rolls the clock back with
> `--exclude-newer`, giving *the newest stable release as of the cutoff* — current
> enough to build, old enough to trust.

> **On `--exclude-newer`.** `uv` expects a concrete cutoff date rather than a
> relative phrase like `"90 days"`, so the tool computes `today − 90 days`
> (configurable via `--exclude-days`) and passes that date. Deterministic for a
> given run date — i.e. reproducible — and the form `uv` actually accepts.

> **Behind a TLS-intercepting proxy?** If uv reports
> `invalid peer certificate: UnknownIssuer`, add `--system-certs` to trust your OS
> certificate store (uv uses its own bundled roots by default).

| | `latest` | `stable` |
| :--- | :--- | :--- |
| Resolution | newest compatible | newest compatible **as of the cutoff** |
| Recent releases | included | excluded (`--exclude-newer`) |
| Pre-releases | per uv default | never (`--prerelease disallow`) |
| Best for | dev, staying current | production, reproducibility |

---

## Package name mapping (PyPI → Conda)

Some projects use different names on PyPI and conda-forge (`Pillow`→`pillow`,
`opencv-python`→`opencv`). The tool ships a built-in `DEFAULT_MAPPING` and lets you
extend or override it with a JSON file:

```json
{
  "opencv-python": "opencv",
  "my-internal-pkg": "my-conda-pkg"
}
```

```bash
python scripts/uv-to-conda.py -i requirements.txt -m my-mapping.json
```

Custom entries override the defaults. Lookups are PEP 503-normalized, so
`Foo.Bar` and `foo-bar` are treated as the same project.

---

## Programmatic use (batch processing)

Every step is a plain function, so you can drive the tool from Python to convert
many environment files at once. Because the file name contains a hyphen, import it
with `importlib`:

```python
import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location("u2c", "scripts/uv-to-conda.py")
u2c = importlib.util.module_from_spec(spec)
spec.loader.exec_module(u2c)

for name in ("core", "ml", "web"):
    u2c.convert(
        input_path=Path(f"reqs/{name}.txt"),
        output_path=Path(f"envs/{name}.yml"),
        env_name=name,
        strategy="stable",
    )
```

Useful building blocks: `parse_requirements`, `resolve_with_uv`,
`load_package_mapping`, `generate_conda_yml`, and the `convert` orchestrator.

---

## Examples

See [`examples/`](examples/). The two `requirements.*.txt` files share the same
package set; the difference is which strategy you resolve them with:

```bash
python scripts/uv-to-conda.py -i scripts/examples/requirements.latest.txt \
    -o scripts/examples/environment.latest.yml -n ds-latest -s latest

python scripts/uv-to-conda.py -i scripts/examples/requirements.stable.txt \
    -o scripts/examples/environment.stable.yml -n ds-stable -s stable
```

The committed `environment.*.yml` files are **genuine `uv` output** (each pins the
full transitive closure — ~113 packages). Exact versions move with the resolution
date and, for `stable`, the 90-day cutoff; each file's header records when it was
generated and how to regenerate it. Comparing them shows the strategy effect — e.g.
`matplotlib` resolves to `3.11.1` under `latest` but `3.10.9` under `stable`.

---

## Integration with `conda-environments`

- Drop generated files under the relevant `python/<version>/environments/` or
  `python/<version>/templates/` directory, following the existing numbering
  (`01-core.yml`, `02-ml.yml`, …) or descriptive naming (`data-science.yml`).
- Match `-p/--python` to the target tree (`3.10` or `3.12`).
- System-level and non-Python packages (`cudatoolkit`, `openssl`, compilers) are
  **out of scope** — add them to the generated `environment.yml` by hand, as the
  existing curated environments do.
- Once curated, lock the environment with the repo's lockfile workflow (see
  `python/<version>/lockfiles/`).

---

## Troubleshooting

| Symptom | Cause / fix |
| :--- | :--- |
| `ERROR: 'uv' was not found` | Install it: `pip install uv`. Only needed for unpinned packages. |
| `ERROR: uv failed to resolve...` | uv's own error is printed below the message — usually an impossible constraint or (as in CI sandboxes) no network / TLS interception. |
| `ERROR: input file not found` | Check the `-i` path. |
| `invalid peer certificate` from uv | A proxy is intercepting TLS; uv suggests `--system-certs`. |
| First package name looks corrupted | The file had a UTF-8 BOM. The tool strips BOMs automatically (`utf-8-sig`); regenerate if you edited it in a BOM-adding editor. |
| Empty `pip:` section warning from conda | Expected — the section is a commented placeholder for PyPI-only packages; fill it or delete it. |
| `~=` pins | Passed through to Conda, which does not support `~=`. Convert such pins to `>=,<` ranges, or move them to the `pip:` section. |

---

## Exit codes

- `0` — success.
- `1` — user-facing error (missing input, `uv` not installed, resolution failure,
  bad mapping file). Temporary files are always cleaned up, even on error.
