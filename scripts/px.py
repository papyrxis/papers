#!/usr/bin/env python3
"""
Usage:
    python scripts/px.py                        # top-level interactive menu
    python scripts/px.py <module> [command] [args]

Modules:
    papers   (p)   Manage LaTeX papers
    resumes  (r)   Manage LaTeX resumes
    roadmaps (rm)  Manage LaTeX roadmaps

Examples:
    python scripts/px.py
    python scripts/px.py papers list
    python scripts/px.py p build 1
    python scripts/px.py resumes build en
    python scripts/px.py r watch fa
    python scripts/px.py roadmaps build all
    python scripts/px.py rm new 02-electronics
"""

from __future__ import annotations

import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR / "lib"))

from common import (
    BOLD, BLUE, CYAN, DIM, GREEN, RED, RESET, YELLOW,
    b, c, dim, error, hr, prompt, warn,
)

# ── module registry ───────────────────────────────────────────────────────────

# (canonical_name, short_alias, filename, description)
MODULES = {
    "papers":   ("p",  "papers.py",   "Manage LaTeX papers"),
    "resumes":  ("r",  "resumes.py",  "Manage LaTeX resumes"),
    "roadmaps": ("rm", "roadmaps.py", "Manage LaTeX roadmaps"),
}

# alias → canonical name
ALIASES: dict[str, str] = {}
for name, (alias, _, _) in MODULES.items():
    ALIASES[name]  = name
    ALIASES[alias] = name


def _dispatch(module_name: str, args: list[str]) -> None:
    """Import the module's main() and invoke it with the given args."""
    _, filename, _ = MODULES[module_name]
    module_path = SCRIPT_DIR / filename

    if not module_path.exists():
        error(f"Module file not found: {module_path}")

    sys.argv = [str(module_path)] + args

    import importlib.util
    spec = importlib.util.spec_from_file_location(module_name, module_path)
    mod  = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    mod.main()


# ── top-level interactive menu ────────────────────────────────────────────────

def _banner() -> None:
    print()
    print(f"  {BOLD}{BLUE}╔════════════════════════════════════════╗{RESET}")
    print(f"  {BOLD}{BLUE}║{RESET}  {BOLD}px{RESET} — Mahdi Mamashli (Genix)        {BOLD}{BLUE}║{RESET}")
    print(f"  {BOLD}{BLUE}╚════════════════════════════════════════╝{RESET}")
    print()


def interactive_menu() -> None:
    _banner()
    print(f"  {c('Choose a module:')}")
    print()

    entries = list(MODULES.items())
    for idx, (name, (alias, _, desc)) in enumerate(entries, 1):
        print(f"  {b(f'[{idx}]')}  {name:<10} ({CYAN}{alias}{RESET})   — {desc}")

    print(f"  {b('[q]')}  quit")
    print()

    choice = prompt("Choice")

    if choice in ("q", "quit"):
        print()
        dim("  Bye!")
        print()
        sys.exit(0)

    # accept digit, alias, or full name
    module = ALIASES.get(choice)
    if not module and choice.isdigit():
        idx = int(choice) - 1
        if 0 <= idx < len(entries):
            module = entries[idx][0]

    if not module:
        warn(f"Unknown choice: {choice!r}")
        interactive_menu()
        return

    # Hand off to the module's own interactive menu (no sub-command)
    _dispatch(module, [])


# ── help ──────────────────────────────────────────────────────────────────────

def cmd_help() -> None:
    print()
    print(f"  {BOLD}px — Genix project CLI{RESET}")
    hr()
    print()
    print(f"  {c('Usage:')}")
    print(f"    python scripts/px.py                        Interactive menu")
    print(f"    python scripts/px.py <module> [cmd] [args]  Run a module command")
    print()
    print(f"  {c('Modules:')}")
    for name, (alias, _, desc) in MODULES.items():
        print(f"    {b(name):<20} alias: {CYAN}{alias}{RESET}   {desc}")
    print()
    print(f"  {c('Examples:')}")
    print(f"    python scripts/px.py papers list")
    print(f"    python scripts/px.py p build 1")
    print(f"    python scripts/px.py p export 1 devto medium")
    print(f"    python scripts/px.py resumes build en")
    print(f"    python scripts/px.py r watch fa")
    print(f"    python scripts/px.py roadmaps build all")
    print(f"    python scripts/px.py rm new 02-electronics")
    print()
    print(f"  {c('Per-module help:')}")
    for name in MODULES:
        print(f"    python scripts/px.py {name} help")
    print()


# ── entry point ───────────────────────────────────────────────────────────────

def main() -> None:
    args = sys.argv[1:]

    if not args:
        interactive_menu()
        return

    first = args[0]

    if first in ("help", "-h", "--help"):
        cmd_help()
        return

    module = ALIASES.get(first)
    if not module:
        error(
            f"Unknown module: {first!r}\n"
            f"  Valid: {', '.join(MODULES)} "
            f"(aliases: {', '.join(a for _, (a, _, _) in MODULES.items())})\n"
            f"  Run: python scripts/px.py help"
        )

    _dispatch(module, args[1:])


if __name__ == "__main__":
    main()