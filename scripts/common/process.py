"""
Subprocess wrappers used across all modules.
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path


def run(
    cmd: list[str],
    cwd: Path | None = None,
    capture: bool = False,
    env: dict | None = None,
) -> subprocess.CompletedProcess:
    """
    Run a command; on non-zero exit print stderr and sys.exit(1).
    Set capture=True to suppress stdout/stderr in normal operation.
    Pass env to override environment variables.
    """
    full_env = os.environ.copy()
    if env:
        full_env.update(env)

    result = subprocess.run(
        cmd,
        cwd=cwd,
        env=full_env,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
    )
    if result.returncode != 0 and not capture:
        sys.exit(result.returncode)
    return result


def run_quiet(
    cmd: list[str],
    cwd: Path | None = None,
    env: dict | None = None,
) -> tuple[int, str, str]:
    """
    Run a command silently and return (returncode, stdout, stderr).
    Never exits — caller decides what to do.
    """
    full_env = os.environ.copy()
    if env:
        full_env.update(env)

    result = subprocess.run(
        cmd,
        cwd=cwd,
        env=full_env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    return result.returncode, result.stdout, result.stderr