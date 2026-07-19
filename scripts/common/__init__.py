"""
common — shared utilities for papers, resumes, roadmaps CLI modules.

All public symbols are re-exported here so existing imports of the form
    from common import foo, bar
continue to work unchanged.
"""

from .base_module import BaseModule
from .colors import (
    BLUE, BOLD, CYAN, DIM, GREEN, GREY, MAGENTA, RED, RESET, YELLOW,
    b, c, dim, error, info, log, success, warn,
)
from .conf import list_conf_files, load_conf, resolve_by_index
from .interactive import choose_from_list, confirm, confirm_slug, prompt
from .latex import LATEX_ARTIFACTS, clean_latex_artifacts, git_describe
from .process import run, run_quiet
from .ui import col, hr
from .watch import dir_checksum, watch_loop

__all__ = [
    # base
    "BaseModule",
    # colors / logging
    "BLUE", "BOLD", "CYAN", "DIM", "GREEN", "GREY", "MAGENTA",
    "RED", "RESET", "YELLOW",
    "b", "c", "dim", "error", "info", "log", "success", "warn",
    # conf
    "list_conf_files", "load_conf", "resolve_by_index",
    # interactive
    "choose_from_list", "confirm", "confirm_slug", "prompt",
    # latex
    "LATEX_ARTIFACTS", "clean_latex_artifacts", "git_describe",
    # process
    "run", "run_quiet",
    # ui
    "col", "hr",
    # watch
    "dir_checksum", "watch_loop",
]