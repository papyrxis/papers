#!/usr/bin/env python3
"""Stage publication PDFs under unique names for GitHub Releases."""

from __future__ import annotations

import argparse
import hashlib
import re
import shutil
import sys
from pathlib import Path


def _asset_name(relative_path: Path) -> str:
    """Build a readable, deterministic asset name from its source path."""
    parts = (*relative_path.parent.parts, relative_path.stem)
    readable = "--".join(parts)
    readable = re.sub(r"[^A-Za-z0-9._-]+", "-", readable).strip("-._")
    readable = (readable or "publication")[:140].rstrip("-._") or "publication"
    digest = hashlib.sha256(relative_path.as_posix().encode("utf-8")).hexdigest()[:12]
    return f"{readable}-{digest}.pdf"


def prepare_release_assets(source_dir: Path, destination_dir: Path) -> list[Path]:
    """Copy all PDFs to a flat directory with collision-resistant filenames."""
    source_dir = source_dir.resolve()
    destination_dir = destination_dir.resolve()

    if not source_dir.is_dir():
        raise ValueError(f"PDF source directory does not exist: {source_dir}")

    try:
        destination_dir.relative_to(source_dir)
    except ValueError:
        pass
    else:
        raise ValueError("PDF destination directory must not be inside the source directory")

    pdfs = sorted(
        (
            path
            for path in source_dir.rglob("*")
            if path.is_file() and path.suffix.lower() == ".pdf"
        ),
        key=lambda path: path.relative_to(source_dir).as_posix(),
    )
    if not pdfs:
        raise ValueError(f"No publication PDFs found in: {source_dir}")

    destination_dir.mkdir(parents=True, exist_ok=True)
    for existing in destination_dir.iterdir():
        if existing.is_file() and existing.suffix.lower() == ".pdf":
            existing.unlink()

    assets: list[Path] = []
    for source in pdfs:
        relative_path = source.relative_to(source_dir)
        target = destination_dir / _asset_name(relative_path)
        if target.exists():
            raise ValueError(f"Generated release asset name collision: {target.name}")
        shutil.copy2(source, target)
        assets.append(target)

    return assets


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Prepare uniquely named PDF assets for a GitHub release."
    )
    parser.add_argument("source_dir", type=Path, help="Directory containing publication PDFs")
    parser.add_argument("destination_dir", type=Path, help="Flat directory for release assets")
    args = parser.parse_args()

    try:
        assets = prepare_release_assets(args.source_dir, args.destination_dir)
    except (OSError, ValueError) as error:
        parser.exit(1, f"error: {error}\n")

    print(f"Prepared {len(assets)} uniquely named PDF release asset(s).")


if __name__ == "__main__":
    main()
