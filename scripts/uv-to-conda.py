#!/usr/bin/env python3
"""uv-to-conda: convert a pip ``requirements.txt`` into a Conda ``environment.yml``.

This utility bridges pip/PyPI dependency specs and Conda environment files for the
``conda-environments`` repository. It reads a ``requirements.txt`` that mixes pinned
packages (e.g. ``numpy==1.26.0``) and unpinned packages (e.g. ``scikit-learn``),
resolves the unpinned ones with `uv <https://github.com/astral-sh/uv>`_, and writes a
valid ``environment.yml``.

Two resolution strategies are supported:

``latest`` (default)
    Resolve unpinned packages to the newest compatible versions.

``stable``
    Resolve unpinned packages to conservative, battle-tested versions: the newest
    stable release as of an ``--exclude-newer`` cutoff (default: 90 days ago), with
    ``--prerelease disallow``. See ``_build_uv_command`` for why bare
    ``--resolution=lowest`` is intentionally avoided on unpinned inputs.

The module is import-safe: every unit of work is a plain function, so it can be
driven programmatically for batch processing as well as through the CLI. Because the
file name contains a hyphen it cannot be imported with a bare ``import`` statement;
see ``scripts/README.md`` for the ``importlib`` one-liner used for programmatic access.

Standard library only. Compatible with Python 3.8+.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tempfile
from datetime import date, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

#: PEP 440 version operators that mark a requirement line as "pinned".
#: Order matters: multi-character operators must be tried before single-character
#: ones so that ``>=`` is not mistaken for ``>``.
VERSION_OPERATORS = ("===", "==", ">=", "<=", "~=", "!=", ">", "<")

#: pip-specific line prefixes that are not package requirements and must be skipped.
PIP_OPTION_PREFIXES = ("-r", "-c", "-e", "--", "-f", "-i")

#: Default number of days a package must have existed before the ``stable`` strategy
#: will consider it. Implemented as a concrete ``--exclude-newer`` cutoff date so the
#: run is deterministic (unlike a relative "90 days" string, which uv does not accept).
DEFAULT_STABLE_WINDOW_DAYS = 90

#: Default PyPI -> Conda package-name mapping. Most names are identical on both
#: ecosystems; the entries that differ (canonical case, dashes) are the ones that
#: matter. Same-name entries are kept for clarity and as documentation.
DEFAULT_MAPPING: Dict[str, str] = {
    "Pillow": "pillow",
    "PyYAML": "pyyaml",
    "PyMySQL": "pymysql",
    "beautifulsoup4": "beautifulsoup4",
    "opencv-python": "opencv",
    "scikit-learn": "scikit-learn",
    "scikit-image": "scikit-image",
    "cryptography": "cryptography",
    "scipy": "scipy",
    "numpy": "numpy",
    "pandas": "pandas",
    "matplotlib": "matplotlib",
    "jupyter": "jupyter",
}


# ---------------------------------------------------------------------------
# Logging helper
# ---------------------------------------------------------------------------

def _log(message: str, verbose: bool) -> None:
    """Print ``message`` to stderr only when ``verbose`` is enabled.

    Diagnostic logging goes to stderr so that stdout can stay reserved for
    machine-consumable output if the tool is ever piped.
    """
    if verbose:
        print(f"[uv-to-conda] {message}", file=sys.stderr)


# ---------------------------------------------------------------------------
# Requirement-name utilities
# ---------------------------------------------------------------------------

def split_name_and_spec(requirement: str) -> Tuple[str, str]:
    """Split a requirement line into ``(name, remainder)``.

    ``numpy==1.26.0`` -> ``("numpy", "==1.26.0")``. A bare name such as
    ``scikit-learn`` yields ``("scikit-learn", "")``. Environment markers and
    extras (``requests[socks]; python_version>'3'``) are stripped from the name so
    that mapping and de-duplication operate on the base project name.
    """
    # Drop any environment marker (everything after a semicolon).
    requirement = requirement.split(";", 1)[0].strip()
    # Drop extras such as ``[socks]`` for name comparison / mapping purposes.
    requirement = re.sub(r"\[.*?\]", "", requirement)

    for operator in VERSION_OPERATORS:
        index = requirement.find(operator)
        if index != -1:
            return requirement[:index].strip(), requirement[index:].strip()
    return requirement.strip(), ""


def normalize_name(name: str) -> str:
    """Return the PEP 503 normalized form of a project name for comparison.

    PyPI treats runs of ``-``, ``_`` and ``.`` as equivalent and is
    case-insensitive, so ``Foo.Bar`` and ``foo-bar`` are the same project.
    """
    return re.sub(r"[-_.]+", "-", name).lower()


def apply_mapping(name: str, mapping: Dict[str, str]) -> str:
    """Map a PyPI package name to its Conda equivalent.

    The lookup is tried first on the exact name (so explicit mapping entries win),
    then on the PEP 503 normalized name so that casing/separator differences still
    resolve. If no mapping applies, the original name is returned unchanged.
    """
    if name in mapping:
        return mapping[name]
    normalized = normalize_name(name)
    for source, target in mapping.items():
        if normalize_name(source) == normalized:
            return target
    return name


# ---------------------------------------------------------------------------
# Task 2: parse_requirements
# ---------------------------------------------------------------------------

def parse_requirements(path: Path) -> Tuple[List[str], List[str]]:
    """Read a ``requirements.txt`` and split it into pinned and unpinned packages.

    Parameters
    ----------
    path:
        Path to the ``requirements.txt`` file.

    Returns
    -------
    (pinned_packages, unpinned_packages)
        ``pinned_packages`` holds full requirement strings that carry a version
        constraint (``numpy==1.26.0``). ``unpinned_packages`` holds bare package
        names with no constraint (``scikit-learn``).

    Notes
    -----
    Comments (``#``), blank lines and pip options (``-r``, ``-c``, ``-e`` ...) are
    skipped. Inline comments (``flask  # web``) are stripped before classification.
    """
    pinned: List[str] = []
    unpinned: List[str] = []

    # ``utf-8-sig`` transparently strips a UTF-8 BOM, which Windows editors often
    # prepend to requirements.txt and which would otherwise corrupt the first name.
    for raw_line in path.read_text(encoding="utf-8-sig").splitlines():
        # Strip inline comments and surrounding whitespace.
        line = raw_line.split("#", 1)[0].strip()
        if not line:
            continue
        # Skip pip-specific options and flags (``-r other.txt``, ``-e .`` ...).
        if line.startswith(PIP_OPTION_PREFIXES):
            continue

        _name, spec = split_name_and_spec(line)
        if spec:  # a version operator was present -> pinned / constrained
            pinned.append(line)
        else:
            unpinned.append(line)

    return pinned, unpinned


# ---------------------------------------------------------------------------
# Task 3: resolve_with_uv
# ---------------------------------------------------------------------------

def _build_uv_command(
    in_file: Path,
    out_file: Path,
    python_version: str,
    strategy: str,
    exclude_days: int,
    system_certs: bool = False,
) -> List[str]:
    """Construct the ``uv pip compile`` argument list for the given strategy."""
    command = [
        "uv",
        "pip",
        "compile",
        str(in_file),
        "--python-version",
        python_version,
        "--output-file",
        str(out_file),
        # Keep resolution self-contained and deterministic across machines.
        "--no-annotate",
        "--no-header",
    ]

    if system_certs:
        # Trust the OS certificate store instead of uv's bundled roots. Needed
        # behind corporate proxies that intercept TLS with a private CA.
        command.append("--system-certs")

    if strategy == "stable":
        # The "stable" intent is battle-tested, production-ready versions: the
        # newest stable release that has had time to prove itself in the wild.
        #
        # We deliberately do NOT use `--resolution=lowest`. On *unpinned* packages
        # (which is precisely this tool's input) "lowest" means the oldest version
        # ever published -- e.g. scikit-learn 0.9 from ~2011 -- which is unbuildable
        # and the opposite of production-ready. uv itself warns against bare
        # `lowest` on unpinned direct dependencies.
        #
        # Instead we take uv's default (highest) resolution but roll the clock back
        # with an `--exclude-newer` cutoff, so we get the newest stable release as
        # of `exclude_days` ago -- current enough to build, old enough to trust --
        # and forbid pre-releases entirely.
        cutoff = (date.today() - timedelta(days=exclude_days)).isoformat()
        command += ["--exclude-newer", cutoff]
        command += ["--prerelease", "disallow"]

    return command


def resolve_with_uv(
    packages: Sequence[str],
    python_version: str = "3.12",
    strategy: str = "latest",
    exclude_days: int = DEFAULT_STABLE_WINDOW_DAYS,
    system_certs: bool = False,
    verbose: bool = False,
) -> List[str]:
    """Resolve unpinned ``packages`` to concrete versions using ``uv pip compile``.

    Parameters
    ----------
    packages:
        Bare, unpinned package names to resolve.
    python_version:
        Target Python version passed to ``uv`` (e.g. ``"3.12"``).
    strategy:
        ``"latest"`` for newest compatible versions, ``"stable"`` for the
        conservative, production-oriented resolution.
    exclude_days:
        For the ``stable`` strategy, ignore releases newer than this many days.
    verbose:
        Emit progress logging to stderr.

    Returns
    -------
    list of ``name==version`` strings, one per resolved package.

    Raises
    ------
    SystemExit
        If ``uv`` is not installed or resolution fails. The underlying ``uv`` error
        output is surfaced so the failure is actionable.
    """
    if not packages:
        return []

    _log(f"Running uv resolution with strategy: {strategy}", verbose)

    # A dedicated temp directory keeps the input/output pair together and lets the
    # ``finally`` block remove everything in one shot, even on failure.
    tmp_dir = Path(tempfile.mkdtemp(prefix="uv-to-conda-"))
    in_file = tmp_dir / "requirements.in"
    out_file = tmp_dir / "requirements.lock"
    try:
        in_file.write_text("\n".join(packages) + "\n", encoding="utf-8")

        command = _build_uv_command(
            in_file, out_file, python_version, strategy, exclude_days, system_certs
        )
        _log("uv command: " + " ".join(command), verbose)

        try:
            result = subprocess.run(
                command,
                capture_output=True,
                text=True,
                check=False,
            )
        except FileNotFoundError:
            # uv is not on PATH.
            print(
                "ERROR: 'uv' was not found. Install it first, e.g. 'pip install uv'\n"
                "       See https://github.com/astral-sh/uv for details.",
                file=sys.stderr,
            )
            raise SystemExit(1)

        if result.returncode != 0:
            print("ERROR: uv failed to resolve the requirements.", file=sys.stderr)
            if result.stderr.strip():
                print(result.stderr.rstrip(), file=sys.stderr)
            raise SystemExit(1)

        resolved = _parse_uv_output(out_file)
        _log(f"Resolved {len(resolved)} package(s).", verbose)
        return resolved
    finally:
        # Always clean up temp files, even if resolution raised.
        for item in (in_file, out_file):
            try:
                item.unlink()
            except OSError:
                pass
        try:
            tmp_dir.rmdir()
        except OSError:
            pass


def _parse_uv_output(out_file: Path) -> List[str]:
    """Extract ``name==version`` lines from a uv-compiled lock file.

    uv writes one requirement per line. Comment lines and continuation/option
    lines (``--hash=...``) are ignored. Only lines carrying an ``==`` pin are kept.
    """
    resolved: List[str] = []
    if not out_file.exists():
        return resolved

    for raw_line in out_file.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or line.startswith("-"):
            continue
        # Keep only the requirement portion (drop trailing ``# via ...`` comments
        # and any hash options separated by whitespace).
        line = line.split("#", 1)[0].strip()
        line = line.split(";", 1)[0].strip()  # drop environment markers
        if "==" in line:
            resolved.append(line)
    return resolved


# ---------------------------------------------------------------------------
# Task 4: load_package_mapping
# ---------------------------------------------------------------------------

def load_package_mapping(
    mapping_path: Optional[Path] = None, verbose: bool = False
) -> Dict[str, str]:
    """Return the PyPI -> Conda name mapping, merging defaults with a JSON override.

    Parameters
    ----------
    mapping_path:
        Optional path to a JSON file of ``{"PyPIName": "conda-name"}`` entries.
        Custom entries override the built-in defaults.
    verbose:
        Emit logging to stderr.

    Raises
    ------
    SystemExit
        If the JSON file is missing or malformed.
    """
    mapping = dict(DEFAULT_MAPPING)
    if mapping_path is None:
        return mapping

    if not mapping_path.exists():
        print(f"ERROR: mapping file not found: {mapping_path}", file=sys.stderr)
        raise SystemExit(1)

    try:
        custom = json.loads(mapping_path.read_text(encoding="utf-8-sig"))
    except json.JSONDecodeError as exc:
        print(f"ERROR: invalid JSON in mapping file {mapping_path}: {exc}",
              file=sys.stderr)
        raise SystemExit(1)

    if not isinstance(custom, dict):
        print("ERROR: mapping file must contain a JSON object of "
              "{\"pypi_name\": \"conda_name\"}.", file=sys.stderr)
        raise SystemExit(1)

    mapping.update({str(k): str(v) for k, v in custom.items()})
    _log(f"Loaded {len(custom)} custom mapping entrie(s) from {mapping_path}.",
         verbose)
    return mapping


# ---------------------------------------------------------------------------
# Task 5: generate_conda_yml
# ---------------------------------------------------------------------------

def _to_conda_spec(requirement: str, mapping: Dict[str, str]) -> str:
    """Convert a pip requirement string into a Conda dependency spec.

    ``numpy==1.26.0`` -> ``numpy=1.26.0`` (Conda's single-``=`` exact pin) with the
    package name mapped to its Conda equivalent. Non-``==`` operators (``>=`` etc.)
    are passed through unchanged, since Conda understands them.
    """
    name, spec = split_name_and_spec(requirement)
    conda_name = apply_mapping(name, mapping)
    # Conda's idiomatic exact pin uses a single '='.
    spec = spec.replace("==", "=", 1)
    return f"{conda_name}{spec}"


def generate_conda_yml(
    pinned_packages: Sequence[str],
    resolved_packages: Sequence[str],
    env_name: str,
    python_version: str,
    channels: Sequence[str],
    output_file: Path,
    mapping: Optional[Dict[str, str]] = None,
    verbose: bool = False,
) -> str:
    """Build and write a Conda ``environment.yml``; return the written content.

    Pinned packages take precedence: a resolved package is only emitted if its
    (normalized) name is not already present among the pinned packages, so no
    duplicate dependency is ever written. Package names are mapped to their Conda
    equivalents. A ``pip:`` subsection is included so PyPI-only packages can be
    added by hand.
    """
    mapping = mapping or dict(DEFAULT_MAPPING)

    lines: List[str] = [f"name: {env_name}", "channels:"]
    lines += [f"  - {channel}" for channel in channels]
    lines.append("dependencies:")
    lines.append(f"  - python={python_version}")

    written_names = set()
    ordered_specs: List[str] = []

    # Pinned first (they win on conflicts).
    for requirement in pinned_packages:
        name, _spec = split_name_and_spec(requirement)
        written_names.add(normalize_name(name))
        ordered_specs.append(_to_conda_spec(requirement, mapping))

    # Resolved second, skipping anything already pinned.
    for requirement in resolved_packages:
        name, _spec = split_name_and_spec(requirement)
        if normalize_name(name) in written_names:
            continue
        written_names.add(normalize_name(name))
        ordered_specs.append(_to_conda_spec(requirement, mapping))

    lines += [f"  - {spec}" for spec in ordered_specs]

    # Always provide pip in the environment plus a pip subsection for PyPI-only
    # packages that have no Conda build.
    lines.append("  - pip")
    lines.append("  - pip:")
    lines.append("      # Add PyPI-only packages here, e.g.:")
    lines.append("      # - some-pypi-only-package==1.2.3")

    content = "\n".join(lines) + "\n"

    if verbose:
        _log(f"Writing {len(ordered_specs) + 1} dependency line(s) to "
             f"{output_file}:", verbose)
        for spec in ["python=" + python_version] + ordered_specs:
            _log(f"  - {spec}", verbose)

    output_file.write_text(content, encoding="utf-8")
    return content


# ---------------------------------------------------------------------------
# Task 6: CLI
# ---------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    """Create the argument parser for the command-line interface."""
    parser = argparse.ArgumentParser(
        prog="uv-to-conda",
        description="Convert a pip requirements.txt into a Conda environment.yml, "
                    "resolving unpinned packages with uv.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "strategies:\n"
            "  latest  resolve unpinned packages to the newest compatible versions\n"
            "  stable  resolve to conservative, battle-tested versions\n"
            "          (--resolution=lowest, --exclude-newer <window>, "
            "--prerelease disallow)\n\n"
            "examples:\n"
            "  uv-to-conda.py -i requirements.txt -o environment.yml -n myenv\n"
            "  uv-to-conda.py -i requirements.txt -o environment.yml -n prod "
            "-s stable\n"
        ),
    )
    parser.add_argument("-i", "--input", default="requirements.txt",
                        help="Input requirements.txt path (default: requirements.txt)")
    parser.add_argument("-o", "--output", default="environment.yml",
                        help="Output environment.yml path (default: environment.yml)")
    parser.add_argument("-n", "--name", default="myenv",
                        help="Conda environment name (default: myenv)")
    parser.add_argument("-p", "--python", default="3.12",
                        help="Target Python version (default: 3.12)")
    parser.add_argument("-c", "--channels", default="conda-forge",
                        help="Comma-separated Conda channels (default: conda-forge)")
    parser.add_argument("-s", "--strategy", choices=["latest", "stable"],
                        default="latest",
                        help="Resolution strategy (default: latest)")
    parser.add_argument("--exclude-days", type=int,
                        default=DEFAULT_STABLE_WINDOW_DAYS,
                        help="For --strategy stable, ignore releases newer than "
                             "this many days (default: %(default)s)")
    parser.add_argument("--system-certs", action="store_true",
                        help="Pass --system-certs to uv (trust the OS certificate "
                             "store; needed behind TLS-intercepting proxies)")
    parser.add_argument("-m", "--mapping", default=None,
                        help="Optional JSON file of PyPI->Conda name mappings")
    parser.add_argument("-v", "--verbose", action="store_true",
                        help="Enable detailed logging to stderr")
    return parser


# ---------------------------------------------------------------------------
# Task 7: main orchestration
# ---------------------------------------------------------------------------

def convert(
    input_path: Path,
    output_path: Path,
    env_name: str = "myenv",
    python_version: str = "3.12",
    channels: Optional[Sequence[str]] = None,
    strategy: str = "latest",
    exclude_days: int = DEFAULT_STABLE_WINDOW_DAYS,
    system_certs: bool = False,
    mapping_path: Optional[Path] = None,
    verbose: bool = False,
) -> str:
    """End-to-end conversion, callable programmatically for batch processing.

    Returns the generated ``environment.yml`` content. Raises ``SystemExit`` on
    user-facing errors (missing input, uv failure) so both the CLI and batch
    callers get consistent behaviour.
    """
    channels = list(channels) if channels else ["conda-forge"]

    if not input_path.exists():
        print(f"ERROR: input file not found: {input_path}", file=sys.stderr)
        raise SystemExit(1)

    pinned, unpinned = parse_requirements(input_path)
    _log(f"Parsed {len(pinned)} pinned package(s) and "
         f"{len(unpinned)} unpinned package(s).", verbose)

    resolved: List[str] = []
    if unpinned:
        _log(f"Resolving {len(unpinned)} unpinned package(s) using "
             f"'{strategy}' strategy...", verbose)
        resolved = resolve_with_uv(
            unpinned,
            python_version=python_version,
            strategy=strategy,
            exclude_days=exclude_days,
            system_certs=system_certs,
            verbose=verbose,
        )
    else:
        _log("No unpinned packages; skipping uv resolution.", verbose)

    mapping = load_package_mapping(mapping_path, verbose=verbose)

    content = generate_conda_yml(
        pinned_packages=pinned,
        resolved_packages=resolved,
        env_name=env_name,
        python_version=python_version,
        channels=channels,
        output_file=output_path,
        mapping=mapping,
        verbose=verbose,
    )
    return content


def main(argv: Optional[Sequence[str]] = None) -> int:
    """CLI entry point. Returns a process exit code (0 = success, 1 = error)."""
    args = build_parser().parse_args(argv)

    channels = [c.strip() for c in args.channels.split(",") if c.strip()]
    input_path = Path(args.input)
    output_path = Path(args.output)
    mapping_path = Path(args.mapping) if args.mapping else None

    convert(
        input_path=input_path,
        output_path=output_path,
        env_name=args.name,
        python_version=args.python,
        channels=channels,
        strategy=args.strategy,
        exclude_days=args.exclude_days,
        system_certs=args.system_certs,
        mapping_path=mapping_path,
        verbose=args.verbose,
    )

    # Success summary (always shown, not just in verbose mode).
    print(f"Wrote Conda environment file: {output_path}")
    print("Create the environment with:\n")
    print(f"    conda env create -f {output_path}\n")
    return 0


if __name__ == "__main__":
    # SystemExit (raised with explicit codes deeper in the call stack) propagates
    # naturally; only KeyboardInterrupt needs friendly handling.
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
        sys.exit(130)
