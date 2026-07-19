"""
ANSI color constants and terminal logging helpers.
"""

from __future__ import annotations

import sys

RESET   = "\033[0m"
BOLD    = "\033[1m"
DIM     = "\033[2m"
RED     = "\033[0;31m"
GREEN   = "\033[0;32m"
YELLOW  = "\033[1;33m"
BLUE    = "\033[0;34m"
CYAN    = "\033[0;36m"
MAGENTA = "\033[0;35m"
GREY    = "\033[0;37m"


def log(msg: str)     -> None: print(f"{BLUE}▶{RESET} {msg}")
def success(msg: str) -> None: print(f"{GREEN}✓{RESET} {msg}")
def warn(msg: str)    -> None: print(f"{YELLOW}⚠{RESET} {msg}")
def info(msg: str)    -> None: print(f"{CYAN}ℹ{RESET} {msg}")
def dim(msg: str)     -> None: print(f"{DIM}{msg}{RESET}")


def error(msg: str, exit_code: int = 1) -> None:
    print(f"{RED}✗{RESET} {msg}", file=sys.stderr)
    sys.exit(exit_code)


def b(text: str) -> str:
    """Return bold text."""
    return f"{BOLD}{text}{RESET}"


def c(text: str) -> str:
    """Return cyan text."""
    return f"{CYAN}{text}{RESET}"