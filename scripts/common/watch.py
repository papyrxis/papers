"""
File-system watch utilities for the papers/resumes/roadmaps CLI.

dir_checksum(paths, patterns)
    Compute a lightweight fingerprint of the files matching `patterns`
    under the given paths (mtime + size, no hashing).  Returns a frozenset
    of (path_str, mtime_ns, size) tuples.

watch_loop(watch_paths, patterns, rebuild_fn, interval)
    Poll for changes every `interval` seconds and call `rebuild_fn()`
    whenever the fingerprint changes.  Runs until Ctrl-C.
"""

from __future__ import annotations

import time
from pathlib import Path
from typing import Callable

from .colors import DIM, GREEN, RESET, warn


# ── fingerprint ───────────────────────────────────────────────────────────────

def dir_checksum(
    paths: list[Path],
    patterns: list[str],
) -> frozenset[tuple[str, int, int]]:
    """
    Return a frozenset of (absolute_path, mtime_ns, size) for every file
    under `paths` that matches at least one glob in `patterns`.

    Works on both individual files and directories:
    - if a path is a file, it is checked directly against the patterns
      (by name) and included if it matches.
    - if a path is a directory, it is searched recursively with rglob.
    """
    entries: set[tuple[str, int, int]] = set()
    for base in paths:
        base = Path(base)
        if not base.exists():
            continue
        if base.is_file():
            if any(base.match(pat) for pat in patterns):
                try:
                    st = base.stat()
                    entries.add((str(base), st.st_mtime_ns, st.st_size))
                except OSError:
                    pass
        else:
            for pat in patterns:
                for fpath in base.rglob(pat):
                    if fpath.is_file():
                        try:
                            st = fpath.stat()
                            entries.add((str(fpath), st.st_mtime_ns, st.st_size))
                        except OSError:
                            pass
    return frozenset(entries)


# ── polling loop ──────────────────────────────────────────────────────────────

def watch_loop(
    watch_paths: list[Path],
    patterns: list[str],
    rebuild_fn: Callable[[], None],
    interval: float = 1.0,
) -> None:
    """
    Poll the filesystem every `interval` seconds.  Call `rebuild_fn()`
    whenever any tracked file changes (mtime or size) or appears/disappears.
    Exits cleanly on KeyboardInterrupt (Ctrl-C).
    """
    last = dir_checksum(watch_paths, patterns)
    print(f"\n  {DIM}Watching for changes — Ctrl-C to stop{RESET}\n")

    try:
        while True:
            time.sleep(interval)
            current = dir_checksum(watch_paths, patterns)
            if current != last:
                changed = {p for p, *_ in current} ^ {p for p, *_ in last}
                if not changed:
                    changed = {
                        p for p, m, s in current
                        if (p, m, s) not in last
                    }
                for p in sorted(changed):
                    print(f"  {GREEN}changed{RESET}  {DIM}{p}{RESET}")
                print()
                try:
                    rebuild_fn()
                except Exception as exc:  # noqa: BLE001
                    warn(f"rebuild failed: {exc}")
                last = dir_checksum(watch_paths, patterns)
    except KeyboardInterrupt:
        print(f"\n  {DIM}Watch stopped.{RESET}\n")