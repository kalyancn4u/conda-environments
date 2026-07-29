#!/usr/bin/env python3
"""Verify that a created environment can import its headline packages.

This is a fast smoke test — it does not exercise functionality, only that the
key packages for a given environment import cleanly on the current interpreter.
Uses the standard library only, so it runs in any of the environments.

Usage
-----
    python verify-env.py --env core        # verify the core package set
    python verify-env.py --env dl           # deep-learning set
    python verify-env.py --all              # every known set
    python verify-env.py --packages numpy pandas   # ad-hoc list

Exit code is non-zero if any import fails, so it is CI-friendly.
"""
from __future__ import annotations

import argparse
import importlib
import platform
import sys

# Map a short environment key to the *import names* (not pip names) that should
# succeed. Keep this in sync with environments/*.yml. Only the headline packages
# are listed — transitive deps are implicitly covered.
ENV_IMPORTS: dict[str, list[str]] = {
    "core": [
        "bs4", "duckdb", "httpx", "IPython", "jupyterlab", "lxml",
        "matplotlib", "numpy", "openpyxl", "pandas", "plotly", "polars",
        "pyarrow", "requests", "scipy", "seaborn", "sklearn", "sqlalchemy",
        "statsmodels", "tqdm", "yaml",
    ],
    "ml": [
        "catboost", "category_encoders", "eli5", "feature_engine", "hdbscan",
        "imblearn", "lightgbm", "mlflow", "mlxtend", "optuna", "shap", "skops",
        "umap", "xgboost",
    ],
    "geo": [
        "contextily", "fiona", "folium", "geoalchemy2", "geopandas",
        "mapclassify", "osgeo", "pyproj", "rasterio", "shapely",
    ],
    "ts": [
        "cmdstanpy", "prophet", "ruptures", "sktime", "statsforecast",
        "statsmodels",
    ],
    "dl": [
        # NOTE: `albumentations` is omitted — its conda-forge build is broken
        # (albucore -> simsimd import failure). See 03-deep-learning.yml.
        "accelerate", "cv2", "datasets", "huggingface_hub",
        "lightning", "onnx", "onnxruntime", "PIL", "safetensors",
        "sentence_transformers", "spacy", "timm", "tokenizers", "torch",
        "torchaudio", "torchvision", "transformers",
    ],
    "tf": ["keras", "tensorboard", "tensorflow"],
    "web": [
        "alembic", "celery", "dash", "django", "fastapi", "flask", "gradio",
        "pydantic", "redis", "sqlalchemy", "streamlit", "uvicorn",
    ],
    "tools": [
        # NOTE: `ruff` is a standalone CLI with no importable Python module, so it
        # is intentionally not listed here (importing it would always fail).
        "cookiecutter", "coverage", "docker", "mypy", "nox", "playwright",
        "pytest", "scrapy", "selenium", "tox",
    ],
    "llm": [
        "accelerate", "datasets", "faiss", "fastapi", "huggingface_hub",
        "sentence_transformers", "tokenizers", "torch", "transformers",
    ],
}

# The all-in-one templates union the modular environments but each picks ONE deep
# learning framework (TF and PyTorch cannot reliably coexist). Derived here so they
# stay in sync automatically.
_TORCH_ONLY = {"accelerate", "lightning", "sentence_transformers", "timm",
               "torch", "torchaudio", "torchvision"}
_COMMON = ("core", "ml", "web", "tools", "geo", "ts")
# all-in-one-pytorch.yml → everything incl. the full PyTorch stack.
ENV_IMPORTS["allinone-pytorch"] = sorted(
    set().union(*(ENV_IMPORTS[k] for k in (*_COMMON, "dl")))
)
# all-in-one-tflow.yml → TensorFlow + the framework-agnostic subset of `dl`.
ENV_IMPORTS["allinone-tflow"] = sorted(
    set().union(*(ENV_IMPORTS[k] for k in (*_COMMON, "tf")))
    | (set(ENV_IMPORTS["dl"]) - _TORCH_ONLY)
)


def check_python(min_minor: int = 12) -> bool:
    """Warn (not fail) if the interpreter is not the expected 3.12 line."""
    major, minor = sys.version_info[:2]
    ok = (major, minor) == (3, min_minor)
    marker = "OK " if ok else "!! "
    print(f"{marker}python {platform.python_version()} "
          f"({'expected 3.12' if not ok else 'as expected'})")
    return ok


def verify(names: list[str]) -> int:
    """Import each name; print a status line; return the count of failures."""
    failures = 0
    width = max((len(n) for n in names), default=0)
    for name in sorted(names):
        try:
            mod = importlib.import_module(name)
            version = getattr(mod, "__version__", "")
            print(f"OK  {name:<{width}}  {version}")
        except Exception as exc:  # noqa: BLE001 — we want to report any failure
            failures += 1
            print(f"!!  {name:<{width}}  IMPORT FAILED: {exc.__class__.__name__}: {exc}")
    return failures


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--env", choices=sorted(ENV_IMPORTS), help="verify a known environment set")
    group.add_argument("--all", action="store_true", help="verify every known set")
    group.add_argument("--packages", nargs="+", metavar="MOD", help="verify an explicit list of import names")
    args = parser.parse_args(argv)

    check_python()
    print("-" * 60)

    if args.packages:
        targets = {"(custom)": args.packages}
    elif args.all:
        targets = ENV_IMPORTS
    else:
        targets = {args.env: ENV_IMPORTS[args.env]}

    total_failures = 0
    for label, names in targets.items():
        print(f"\n[{label}]")
        total_failures += verify(names)

    print("-" * 60)
    if total_failures:
        print(f"FAILED: {total_failures} import(s) did not succeed.")
        return 1
    print("SUCCESS: all imports succeeded.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
