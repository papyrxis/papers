"""
Bash-style .conf file parser and slug/index resolver.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from .colors import error


def load_conf(path: Path) -> dict:
    """
    Parse a bash-style .conf file into a Python dict.

    Handles:
      KEY="value"          → str
      KEY='value'          → str
      KEY=bare             → str
      KEY=(a b c)          → list[str]
      KEY=("a b" c)        → list[str]
      # comments           → ignored
      blank lines          → ignored
    """
    text = path.read_text(encoding="utf-8").replace("\r", "")
    conf: dict = {}

    i = 0
    lines = text.split("\n")
    while i < len(lines):
        line = lines[i].strip()
        i += 1

        if not line or line.startswith("#"):
            continue

        m = re.match(r'^([A-Z_][A-Z0-9_]*)=(.*)', line)
        if not m:
            continue

        key, rest = m.group(1), m.group(2).strip()

        if rest.startswith("("):
            buf = rest
            while ")" not in buf and i < len(lines):
                buf += " " + lines[i].strip()
                i += 1
            inner = re.search(r'\((.*?)\)', buf, re.S)
            if inner:
                raw = inner.group(1)
                items = re.findall(r'"([^"]*)"|(\'[^\']*\')|(\S+)', raw)
                result = []
                for dq, sq, bare in items:
                    if dq:
                        result.append(dq)
                    elif sq:
                        result.append(sq.strip("'"))
                    elif bare:
                        result.append(bare)
                conf[key] = result
            else:
                conf[key] = []
        else:
            val = rest.strip('"').strip("'")
            conf[key] = val

    return conf


def list_conf_files(conf_dir: Path) -> list[Path]:
    """Return sorted *.conf files in conf_dir."""
    return sorted(conf_dir.glob("*.conf"))


def resolve_by_index(conf_dir: Path, value: str) -> str:
    """
    Resolve a numeric index (1-based) or a direct name to a conf stem.

    e.g.  "1"  → "01-the-nature-of-data"
          "en" → "en"
    Returns the stem (filename without .conf).
    Calls sys.exit(1) on failure.
    """
    confs = list_conf_files(conf_dir)
    if not confs:
        error(f"No .conf files found in {conf_dir}")

    if value.isdigit():
        idx = int(value)
        if idx < 1 or idx > len(confs):
            error(f"No item at index {idx} (valid: 1–{len(confs)})")
        return confs[idx - 1].stem

    target = conf_dir / f"{value}.conf"
    if not target.exists():
        stems = [c.stem for c in confs]
        error(
            f"Unknown item '{value}'.\n"
            f"  Valid names: {', '.join(stems)}\n"
            f"  Or use a number 1–{len(confs)}"
        )
    return value