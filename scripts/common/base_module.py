"""
Abstract base class shared by Papers, Resumes, and Roadmaps CLI modules.

Subclasses define:
  - name        str          display name  ("Papers")
  - script_name str          script filename ("papers.py")
  - commands    dict         { "cmd": (fn, "description"), … }
  - menu_items  list[tuple]  [ ("key", "cmd", "label"), … ]

The base provides: banner, interactive_menu, cmd_help, main.
"""

from __future__ import annotations

import sys
from abc import ABC, abstractmethod
from typing import Callable

from .colors import BLUE, BOLD, RESET, b, c, dim, error, warn
from .interactive import prompt
from .ui import hr


class BaseModule(ABC):

    # ── subclass contract ─────────────────────────────────────────────────────

    @property
    @abstractmethod
    def name(self) -> str:
        """Human-readable module name, e.g. 'Papers'."""

    @property
    @abstractmethod
    def script_name(self) -> str:
        """Script filename, e.g. 'papers.py'."""

    @property
    @abstractmethod
    def commands(self) -> dict[str, tuple[Callable, str]]:
        """
        Mapping of command name → (handler_fn, one-line description).
        handler_fn is called with the remaining CLI args unpacked.
        """

    @property
    @abstractmethod
    def menu_items(self) -> list[tuple[str, str, str]]:
        """
        Items for the interactive menu.
        Each tuple: (key, command_name, display_label)
          key          — what the user types, e.g. "1"
          command_name — must be a key in self.commands, or the special
                         literal "all" (calls cmd_build("all"))
          display_label — shown to the right of the key
        """

    # ── shared banner ─────────────────────────────────────────────────────────

    def _banner(self) -> None:
        width  = 38
        suffix = " — Mahdi Mamashli (Genix)"
        print()
        print(f"  {BOLD}{BLUE}╔{'═' * width}╗{RESET}")
        print(f"  {BOLD}{BLUE}║{RESET}  {BOLD}{self.name}{RESET}{suffix}  {BOLD}{BLUE}║{RESET}")
        print(f"  {BOLD}{BLUE}╚{'═' * width}╝{RESET}")
        print()

    # ── shared interactive menu ───────────────────────────────────────────────

    def interactive_menu(self) -> None:
        self._banner()
        print(f"  {c('What would you like to do?')}")
        print()

        dispatch: dict[str, Callable] = {}
        for key, cmd_name, label in self.menu_items:
            print(f"  {b(f'[{key}]')}  {label}")
            if cmd_name == "all":
                dispatch[key] = lambda: self.commands["build"][0]("all")
            else:
                fn = self.commands[cmd_name][0]
                dispatch[key]      = fn
                dispatch[cmd_name] = fn  # also accept the word directly

        quit_fn = lambda: (print(), dim("  Bye!"), print(), sys.exit(0))
        dispatch["q"]    = quit_fn
        dispatch["quit"] = quit_fn
        print(f"  {b('[q]')}  quit")
        print()

        choice = prompt("Choice")
        fn = dispatch.get(choice)
        if fn:
            fn()
        else:
            warn(f"Unknown choice: {choice!r}")
            self.interactive_menu()

    # ── shared help ───────────────────────────────────────────────────────────

    def cmd_help(self) -> None:
        print()
        print(f"  {BOLD}{self.name} CLI — Genix{RESET}")
        hr()
        print()
        print(f"  {c('Usage:')}")
        sn = self.script_name
        print(f"    python scripts/{sn}                   Interactive menu")
        print(f"    python scripts/{sn} <command> [args]  Direct command")
        print()
        print(f"  {c('Commands:')}")
        for cmd_name, (_, desc) in self.commands.items():
            print(f"    {b(cmd_name):<20} {desc}")
        print(f"    {'help':<20} Show this help")
        print()

    # ── shared main ───────────────────────────────────────────────────────────

    def main(self) -> None:
        args = sys.argv[1:]
        if not args:
            self.interactive_menu()
            return

        cmd  = args[0]
        rest = args[1:]

        if cmd in ("help", "-h", "--help"):
            self.cmd_help()
            return

        entry = self.commands.get(cmd)
        if entry is None:
            error(
                f"Unknown command: {cmd!r}\n"
                f"  Valid: {', '.join(self.commands)}\n"
                f"  Run: python scripts/{self.script_name} help"
            )

        fn, _ = entry
        fn(*rest)