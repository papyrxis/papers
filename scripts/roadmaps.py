#!/usr/bin/env python3
"""
Usage:
    python scripts/roadmaps.py                    # interactive menu
    python scripts/roadmaps.py <command> [args]   # direct command

Commands:
    list                   List all roadmaps & build status
    build  <slug|#|all>    Build roadmap(s) to PDF
    watch  <slug|#>        Auto-rebuild on file change
    new    <slug>          Scaffold a new roadmap
    clean  [slug|#]        Remove build artifacts
    delete <slug|#>        Delete a roadmap completely
    help                   Show this help
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT       = SCRIPT_DIR.parent
sys.path.insert(0, str(SCRIPT_DIR))

from common import (                                          # noqa: E402
    BOLD, CYAN, DIM, GREEN, RED, RESET, YELLOW, BLUE,
    BaseModule,
    b, c,
    clean_latex_artifacts, confirm_slug, error, hr,
    list_conf_files, load_conf, log, prompt,
    resolve_by_index, success, warn, watch_loop, git_describe,
)

CONFIGS_ROADMAPS = ROOT / "configs" / "roadmaps"
ROADMAPS_DIR     = ROOT / "roadmaps"
BUILD_DIR        = ROOT / "build"


# ── list ──────────────────────────────────────────────────────────────────────

def cmd_list() -> None:
    print()
    print(f"  {BOLD}Roadmaps — Genix{RESET}")
    hr()
    print(f"  {'#':<4}  {'Slug':<40}  {'Built':<6}  Title")
    hr()

    confs = list_conf_files(CONFIGS_ROADMAPS)
    for idx, conf in enumerate(confs, 1):
        slug  = conf.stem
        meta  = load_conf(conf)
        title = meta.get("ROADMAP_TITLE", slug)

        out_dir = BUILD_DIR / slug
        built   = (
            f"{GREEN}yes{RESET}"
            if out_dir.exists() and list(out_dir.glob("*.pdf"))
            else f"{RED}no{RESET}"
        )

        short = title[:48] + ("…" if len(title) > 48 else "")
        print(f"  [{idx}]   {slug:<40}  {built}    {short}")

    hr()
    print(f"  {len(confs)} roadmap(s) total")
    print()
    print(f"  {c('Build one:')}   python scripts/roadmaps.py build <slug|#>")
    print(f"  {c('Build all:')}   python scripts/roadmaps.py build all")
    print()


# ── build ─────────────────────────────────────────────────────────────────────

def _build_one(slug: str) -> bool:
    conf_path   = CONFIGS_ROADMAPS / f"{slug}.conf"
    roadmap_dir = ROADMAPS_DIR / slug

    if not conf_path.exists():
        warn(f"Unknown roadmap '{slug}' (no {conf_path})")
        return False
    if not roadmap_dir.exists():
        warn(f"Roadmap directory not found: {roadmap_dir}")
        return False
    if not (roadmap_dir / "main.tex").exists():
        warn(f"main.tex not found in {roadmap_dir} — run: python scripts/roadmaps.py new {slug}")
        return False

    meta   = load_conf(conf_path)
    engine = meta.get("ENGINE", "pdflatex")
    title  = meta.get("ROADMAP_TITLE", slug)

    import shutil as _shutil
    import platform as _platform

    def _find_engine(name: str) -> str:
        """Return full path to *name* if found, else return *name* (let subprocess fail gracefully)."""
        found = _shutil.which(name)
        if found:
            return found
        if _platform.system() == "Windows":
            candidates = [
                rf"C:\texlive\2024\bin\windows\{name}.exe",
                rf"C:\texlive\2023\bin\windows\{name}.exe",
                rf"C:\texlive\2022\bin\win32\{name}.exe",
                rf"C:\Program Files\MiKTeX\miktex\bin\x64\{name}.exe",
                rf"C:\Program Files\MiKTeX 2.9\miktex\bin\x64\{name}.exe",
            ]
            for c in candidates:
                if os.path.isfile(c):
                    return c
        return name  # fall back — subprocess will raise FileNotFoundError with a clear message

    engine_path = _find_engine(engine)
    if engine_path == engine and not _shutil.which(engine):
        error(
            f"Engine '{engine}' not found on PATH.\n"
            f"  • On Windows: make sure TeX Live / MiKTeX bin folder is on your PATH.\n"
            f"    e.g.  set PATH=C:\\texlive\\2024\\bin\\windows;%PATH%\n"
            f"  • On WSL/Linux: run  sudo apt install texlive-full"
        )

    log(f"[{slug}] compiling with {engine_path}…")
    out_dir = BUILD_DIR / slug
    out_dir.mkdir(parents=True, exist_ok=True)

    env = os.environ.copy()
    env.update({
        "TEXINPUTS":       f".:{roadmap_dir}:{ROOT}::",
        "PROJECT_VERSION": git_describe(ROOT),
        "BUILD_DATE":      datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
    })

    def _run_engine() -> subprocess.CompletedProcess:
        proc = subprocess.run(
            [engine_path, "-interaction=nonstopmode",
             f"-output-directory={out_dir}", "main.tex"],
            cwd=roadmap_dir,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            env=env,
        )
        try:
            stdout = proc.stdout.decode("utf-8")
        except UnicodeDecodeError:
            stdout = proc.stdout.decode("latin-1")
        proc.__dict__["_stdout_text"] = stdout
        return proc

    def _stdout(proc: subprocess.CompletedProcess) -> str:
        return proc.__dict__.get("_stdout_text", "")

    _run_engine()          # pass 1 — builds .toc / .aux / TikZ externals
    result = _run_engine() # pass 2 — resolves TOC entries, LastPage, overlays
    for line in _stdout(result).splitlines():
        if any(x in line for x in ("! ", "l.", "Error", "Warning")):
            print(f"  {line}")

    src = out_dir / "main.pdf"
    if not src.exists():
        warn(f"[{slug}] build finished but {src} not found — check {out_dir / 'main.log'}")
        return False

    year     = meta.get("ROADMAP_YEAR", datetime.now(timezone.utc).strftime("%Y"))
    safe     = re.sub(r'[^A-Za-z0-9_-]', '', title.replace(" ", "_"))
    out_name = f"{year}_Genix_{safe}.pdf"
    dst      = BUILD_DIR / out_name
    shutil.copy2(src, dst)

    success(f"[{slug}] done → build/{out_name}")
    return True


def cmd_build(target: str = "") -> None:
    if not target:
        print()
        print(f"  {BOLD}Build Roadmap{RESET}")
        print()
        cmd_list()
        target = prompt("Slug to build (or 'all')")
        if not target:
            error("Slug cannot be empty.")

    if target == "all":
        passed, failed = [], []
        for conf in list_conf_files(CONFIGS_ROADMAPS):
            slug = conf.stem
            if _build_one(slug):
                passed.append(slug)
            else:
                failed.append(slug)
        print()
        success(f"Build summary: {len(passed)} passed, {len(failed)} failed")
        for s in passed: print(f"  {GREEN}✓{RESET} {s}")
        for s in failed: print(f"  {RED}✗{RESET} {s}")
        if failed:
            sys.exit(1)
    else:
        slug = resolve_by_index(CONFIGS_ROADMAPS, target)
        if not _build_one(slug):
            sys.exit(1)


# ── watch ─────────────────────────────────────────────────────────────────────

def cmd_watch(slug_input: str = "") -> None:
    if not slug_input:
        cmd_list()
        slug_input = prompt("Slug to watch")
        if not slug_input:
            error("Slug cannot be empty.")

    slug        = resolve_by_index(CONFIGS_ROADMAPS, slug_input)
    roadmap_dir = ROADMAPS_DIR / slug

    log(f"Watch mode on roadmaps/{slug} — Ctrl+C to stop")
    _build_one(slug)

    watch_loop(
        watch_paths=[roadmap_dir, ROADMAPS_DIR / "shared",
                     CONFIGS_ROADMAPS / f"{slug}.conf"],
        patterns=["*.tex", "*.conf"],
        rebuild_fn=lambda: _build_one(slug),
    )


# ── new ───────────────────────────────────────────────────────────────────────

def cmd_new(slug: str = "") -> None:
    if not slug:
        print()
        print(f"  {BOLD}New Roadmap{RESET}")
        print()
        slug = prompt("Slug (e.g. 02-electronics-roadmap)")
        if not slug:
            error("Slug cannot be empty.")

    roadmap_dir = ROADMAPS_DIR / slug
    conf_path   = CONFIGS_ROADMAPS / f"{slug}.conf"

    if roadmap_dir.exists():
        error(f"Roadmap already exists: roadmaps/{slug}")
    if conf_path.exists():
        error(f"Config already exists: configs/roadmaps/{slug}.conf")

    raw   = re.sub(r'^[0-9]+-', '', slug)
    title = re.sub(r'-', ' ', raw).upper()
    year  = datetime.now(timezone.utc).strftime("%Y")

    log(f"Scaffolding: roadmaps/{slug}")

    roadmap_dir.mkdir(parents=True, exist_ok=True)
    (roadmap_dir / "sections").mkdir(exist_ok=True)
    CONFIGS_ROADMAPS.mkdir(parents=True, exist_ok=True)

    conf_path.write_text(
        f"""\
ROADMAP_TITLE="{title}"
ROADMAP_SUBTITLE="Complete Checklist"
ROADMAP_AUTHOR="Mahdi Mamashli (Genix)"
ROADMAP_EMAIL="bitsgenix@gmail.com"
ROADMAP_YEAR="{year}"
ROADMAP_GITHUB="github.com/papyrxis/Arliz"
ROADMAP_LICENSE="Creative Commons — Open Source"

PDF_TITLE="{title}"
PDF_SUBJECT=""
PDF_KEYWORDS=""

BRAND_NAVY="0.098 0.176 0.333"
BRAND_BLUE="0 0.337 0.702"
BRAND_GOLD="0.784 0.608 0.196"

ENGINE="pdflatex"
BIBTEX="none"

SECTIONS=(
  "sections/00-north-star"
  "sections/01-content"
)
""",
        encoding="utf-8",
    )

    (roadmap_dir / "sections" / "00-north-star.tex").write_text(
        """\
% sections/00-north-star.tex
\\section*{North Star}

What is the ultimate goal of this roadmap?
""",
        encoding="utf-8",
    )

    (roadmap_dir / "sections" / "01-content.tex").write_text(
        """\
% sections/01-content.tex
\\section{Content}

Start writing roadmap content here.
""",
        encoding="utf-8",
    )

    _generate_main_tex(slug)

    print()
    success(f"Scaffolded: roadmaps/{slug}")
    print()
    print(f"  {c('Next steps:')}")
    print(f"    1. Edit config:     configs/roadmaps/{slug}.conf")
    print(f"    2. Write sections:  roadmaps/{slug}/sections/*.tex")
    print(f"    3. Build:           python scripts/roadmaps.py build {slug}")
    print()


def _generate_main_tex(slug: str) -> None:
    """Generate roadmaps/<slug>/main.tex from conf + shared preamble."""
    conf_path   = CONFIGS_ROADMAPS / f"{slug}.conf"
    roadmap_dir = ROADMAPS_DIR / slug

    if not conf_path.exists():
        error(f"No config for roadmap '{slug}' (expected {conf_path})")

    meta         = load_conf(conf_path)
    title        = meta.get("ROADMAP_TITLE", slug)
    author       = meta.get("ROADMAP_AUTHOR", "Mahdi Mamashli (Genix)")
    email        = meta.get("ROADMAP_EMAIL", "bitsgenix@gmail.com")
    year         = meta.get("ROADMAP_YEAR", datetime.now(timezone.utc).strftime("%Y"))
    github       = meta.get("ROADMAP_GITHUB", "")
    license_     = meta.get("ROADMAP_LICENSE", "Creative Commons — Open Source")
    subtitle     = meta.get("ROADMAP_SUBTITLE", "")
    pdf_title    = meta.get("PDF_TITLE", title)
    pdf_subject  = meta.get("PDF_SUBJECT", "")
    pdf_keywords = meta.get("PDF_KEYWORDS", "")
    sections     = meta.get("SECTIONS", [])

    sections_block = "\n".join(
        f"\\input{{{s}}}\n\\newpage" for s in sections
    )

    main_tex = f"""\
% roadmaps/{slug}/main.tex
%
% AUTO-GENERATED by scripts/roadmaps.py — do not edit directly.
% Edit configs/roadmaps/{slug}.conf and re-run:
%   python scripts/roadmaps.py build {slug}

\\documentclass[10pt,a4paper]{{article}}

\\input{{../../roadmaps/shared/preamble}}

\\hypersetup{{
  pdftitle={{{pdf_title}}},
  pdfauthor={{{author}}},
  pdfsubject={{{pdf_subject}}},
  pdfkeywords={{{pdf_keywords}}},
}}

% ─── Document ──────────────────────────────────────────────────────────────────
\\begin{{document}}

{sections_block}

\\end{{document}}
"""
    output = roadmap_dir / "main.tex"
    output.write_text(main_tex, encoding="utf-8")
    print(f"generated {output.relative_to(ROOT)}")


# ── clean ─────────────────────────────────────────────────────────────────────

def cmd_clean(slug_input: str = "") -> None:
    if slug_input:
        slug = resolve_by_index(CONFIGS_ROADMAPS, slug_input)
        log(f"Cleaning build artifacts for: {slug}")

        build_slug = BUILD_DIR / slug
        if build_slug.exists():
            shutil.rmtree(build_slug)

        roadmap_dir = ROADMAPS_DIR / slug
        if roadmap_dir.exists():
            clean_latex_artifacts(roadmap_dir)

        meta  = load_conf(CONFIGS_ROADMAPS / f"{slug}.conf")
        title = meta.get("ROADMAP_TITLE", slug)
        year  = meta.get("ROADMAP_YEAR", datetime.now(timezone.utc).strftime("%Y"))
        safe  = re.sub(r'[^A-Za-z0-9_-]', '', title.replace(" ", "_"))
        for f in BUILD_DIR.glob(f"*{safe}*.pdf"):
            f.unlink()

        success(f"Cleaned {slug}")
    else:
        log("Cleaning all roadmap build artifacts…")
        if ROADMAPS_DIR.exists():
            clean_latex_artifacts(ROADMAPS_DIR)

        for conf in list_conf_files(CONFIGS_ROADMAPS):
            slug = conf.stem
            bd   = BUILD_DIR / slug
            if bd.exists():
                shutil.rmtree(bd)

        success("All roadmap artifacts cleaned")


# ── delete ────────────────────────────────────────────────────────────────────

def cmd_delete(slug_input: str = "") -> None:
    if not slug_input:
        print()
        print(f"  {BOLD}Delete Roadmap{RESET}")
        print()
        cmd_list()
        slug_input = prompt("Slug to delete")
        if not slug_input:
            error("Slug cannot be empty.")

    slug        = resolve_by_index(CONFIGS_ROADMAPS, slug_input)
    roadmap_dir = ROADMAPS_DIR / slug
    conf_path   = CONFIGS_ROADMAPS / f"{slug}.conf"

    if not roadmap_dir.exists() and not conf_path.exists():
        error(f"Nothing to delete for '{slug}'")

    print()
    warn("This will permanently delete:")
    if roadmap_dir.exists():  print(f"    roadmaps/{slug}/")
    if conf_path.exists():    print(f"    configs/roadmaps/{slug}.conf")
    bd = BUILD_DIR / slug
    if bd.exists():           print(f"    build/{slug}/")
    print()

    if not confirm_slug(slug):
        error("Confirmation did not match — nothing deleted.")

    if roadmap_dir.exists(): shutil.rmtree(roadmap_dir)
    if conf_path.exists():   conf_path.unlink()
    if bd.exists():          shutil.rmtree(bd)

    success(f"Deleted: {slug}")
    print()


# ── module class ──────────────────────────────────────────────────────────────

class RoadmapsModule(BaseModule):
    @property
    def name(self) -> str:
        return "Roadmaps"

    @property
    def script_name(self) -> str:
        return "roadmaps.py"

    @property
    def commands(self) -> dict:
        return {
            "list":   (cmd_list,   "                  List all roadmaps & build status"),
            "build":  (cmd_build,  "<slug|#|all>      Build roadmap(s) to PDF"),
            "watch":  (cmd_watch,  "<slug|#>          Auto-rebuild on file change"),
            "new":    (cmd_new,    "<slug>             Scaffold a new roadmap"),
            "clean":  (cmd_clean,  "[slug|#]          Remove build artifacts"),
            "delete": (cmd_delete, "<slug|#>          Delete a roadmap completely"),
        }

    @property
    def menu_items(self) -> list[tuple]:
        return [
            ("1", "build",  "build     — Build a roadmap to PDF"),
            ("2", "all",    "build all — Build all roadmaps"),
            ("3", "watch",  "watch     — Watch mode (auto-rebuild)"),
            ("4", "new",    "new       — Scaffold a new roadmap"),
            ("5", "list",   "list      — Show roadmap list"),
            ("6", "clean",  "clean     — Remove build artifacts"),
            ("7", "delete", "delete    — Delete a roadmap completely"),
        ]


# ── entry point ───────────────────────────────────────────────────────────────

def main() -> None:
    RoadmapsModule().main()


if __name__ == "__main__":
    main()