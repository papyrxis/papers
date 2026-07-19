"""
LaTeX-specific helpers: artifact cleanup patterns and git describe.
"""

from __future__ import annotations

from pathlib import Path

from .process import run_quiet

LATEX_ARTIFACTS = (
    "*.aux", "*.log", "*.out", "*.toc", "*.bbl", "*.blg",
    "*.synctex.gz", "*.fdb_latexmk", "*.fls",
    "*.idx", "*.ilg", "*.ind", "*.run.xml", "*.bcf",
)


def clean_latex_artifacts(directory: Path) -> int:
    """Remove LaTeX intermediate files from directory recursively. Returns count."""
    removed = 0
    for pat in LATEX_ARTIFACTS:
        for f in directory.rglob(pat):
            try:
                f.unlink()
                removed += 1
            except OSError:
                pass
    return removed


def git_describe(root: Path) -> str:
    """Return `git describe` output or 'dev'."""
    rc, out, _ = run_quiet(
        ["git", "-C", str(root), "describe", "--tags", "--always", "--dirty"],
    )
    return out.strip() if rc == 0 and out.strip() else "dev"