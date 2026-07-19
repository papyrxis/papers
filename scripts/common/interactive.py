"""
Interactive CLI helpers: prompt, confirm, choose_from_list.
"""

from __future__ import annotations

import sys

from .colors import BOLD, CYAN, RESET, warn


def prompt(text: str, default: str = "") -> str:
    """Read a line from stdin with an optional default."""
    suffix = f" [{default}]" if default else ""
    try:
        val = input(f"  {text}{suffix}: ").strip()
    except (EOFError, KeyboardInterrupt):
        print()
        sys.exit(0)
    return val if val else default


def confirm(text: str) -> bool:
    """Ask a yes/no question; return True for y/Y."""
    try:
        val = input(f"  {text} [y/N]: ").strip().lower()
    except (EOFError, KeyboardInterrupt):
        print()
        return False
    return val in ("y", "yes")


def confirm_slug(slug: str) -> bool:
    """Ask the user to type the slug back to confirm a destructive action."""
    try:
        val = input(f"  Type the slug to confirm ({slug}): ").strip()
    except (EOFError, KeyboardInterrupt):
        print()
        return False
    return val == slug


def choose_from_list(items: list[str], prompt_text: str) -> str:
    """
    Display a numbered list and return the chosen item.
    Accepts a number or the item name directly.
    """
    for i, item in enumerate(items, 1):
        print(f"  {BOLD}[{i}]{RESET}  {item}")
    print()
    while True:
        raw = prompt(prompt_text)
        if raw.isdigit():
            idx = int(raw)
            if 1 <= idx <= len(items):
                return items[idx - 1]
        elif raw in items:
            return raw
        warn(f"Invalid choice: {raw!r}")