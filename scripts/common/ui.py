"""
Terminal UI helpers: horizontal rules, column formatting, banner drawing.
"""

from __future__ import annotations

import re

from .colors import RESET


def hr(width: int = 70) -> None:
    print(f"  {'─' * width}")


def col(text: str, width: int, color: str = "") -> str:
    """Left-pad text in an ANSI-aware column (color codes don't count)."""
    visible = re.sub(r'\033\[[0-9;]*m', '', text)
    pad = max(0, width - len(visible))
    return (color + text + RESET if color else text) + " " * pad