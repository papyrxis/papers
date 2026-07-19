#!/usr/bin/env python3
"""
Usage:
    python scripts/resumes.py                    # interactive menu
    python scripts/resumes.py <command> [args]   # direct command

Commands:
    list                          List all resumes & build status
    build  <lang|#|all>           Build resume(s) to PDF
    watch  <lang|#>               Auto-rebuild on file change
    rename <lang|#> [new-name]    Set output PDF name
    clean  [lang|#]               Remove build artifacts
    help                          Show this help
"""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT       = SCRIPT_DIR.parent
sys.path.insert(0, str(SCRIPT_DIR))

from common import (                                          # noqa: E402
    BOLD, CYAN, DIM, GREEN, RED, RESET, YELLOW, BLUE,
    BaseModule,
    b, c,
    clean_latex_artifacts, error, hr, info,
    list_conf_files, load_conf, log, prompt,
    resolve_by_index, success, warn, watch_loop,
)

CONFIGS_RESUMES = ROOT / "configs" / "resumes"
RESUMES_DIR     = ROOT / "resumes"
BUILD_DIR       = ROOT / "build"


# ── language description ──────────────────────────────────────────────────────

def lang_desc(lang: str) -> str:
    return {
        "en": "English  — xelatex, Charter, single-page",
        "fa": "فارسی    — xelatex, Vazirmatn, RTL (Awesome-CV)",
    }.get(lang, "Unknown")


# ── list ──────────────────────────────────────────────────────────────────────

def cmd_list() -> None:
    print()
    print(f"  {BOLD}Resumes — Genix{RESET}")
    hr()
    print(f"  {'#':<4}  {'Lang':<6}  {'Built':<8}  {'Output name':<28}  Description")
    hr()

    for idx, conf in enumerate(list_conf_files(CONFIGS_RESUMES), 1):
        lang = conf.stem
        meta = load_conf(conf)
        out  = meta.get("OUTPUT_NAME", "resume")
        desc = lang_desc(lang)

        built = (
            f"{GREEN}yes{RESET}"
            if (BUILD_DIR / f"{out}.pdf").exists()
            else f"{RED}no{RESET}"
        )

        print(f"  [{idx}]   {lang:<6}  ", end="")
        print(f"{built}       {out + '.pdf':<28}  {desc}")

    hr()
    print()
    print(f"  {c('Build one:')}   python scripts/resumes.py build <lang|#>")
    print(f"  {c('Build all:')}   python scripts/resumes.py build all")
    print(f"  {c('Rename:')}      Edit OUTPUT_NAME in configs/resumes/<lang>.conf")
    print()


# ── build ─────────────────────────────────────────────────────────────────────

def _build_one(lang: str) -> bool:
    conf_path  = CONFIGS_RESUMES / f"{lang}.conf"
    resume_dir = RESUMES_DIR / lang

    if not conf_path.exists():
        warn(f"Unknown resume lang '{lang}' (no {conf_path})")
        return False
    if not resume_dir.exists():
        warn(f"Resume directory not found: {resume_dir}")
        return False
    if not (resume_dir / "resume.tex").exists():
        warn(f"resume.tex not found in {resume_dir}")
        return False

    meta   = load_conf(conf_path)
    engine = meta.get("ENGINE", "xelatex")
    out    = meta.get("OUTPUT_NAME", "Mahdi-Mamashli-Resume")

    log(f"[{lang}] compiling with {engine}…")
    out_dir = BUILD_DIR / "resumes" / lang
    out_dir.mkdir(parents=True, exist_ok=True)

    result = subprocess.run(
        [engine, "-interaction=nonstopmode",
         f"-output-directory={out_dir}", "resume.tex"],
        cwd=resume_dir,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    for line in result.stdout.splitlines():
        if any(x in line for x in ("! ", "l.", "Error", "Warning")):
            print(f"  {line}")

    src = out_dir / "resume.pdf"
    dst = BUILD_DIR / f"{out}.pdf"

    if not src.exists():
        warn(f"[{lang}] build finished but {src} not found — check {out_dir / 'resume.log'}")
        return False

    shutil.copy2(src, dst)
    success(f"[{lang}] done → build/{out}.pdf")
    return True


def cmd_build(target: str = "") -> None:
    if not target:
        print()
        print(f"  {BOLD}Build Resume{RESET}")
        print()
        cmd_list()
        print(f"  {c('Which resume?')}")
        print(f"  Enter a lang code (en, fa), a number (#), or 'all'.")
        print()
        target = prompt("Choice")
        if not target:
            error("No choice made.")

    if target == "all":
        passed, failed = [], []
        for conf in list_conf_files(CONFIGS_RESUMES):
            lang = conf.stem
            if _build_one(lang):
                passed.append(lang)
            else:
                failed.append(lang)
        print()
        success(f"Build summary: {len(passed)} passed, {len(failed)} failed")
        for lang in passed: print(f"  {GREEN}✓{RESET} {lang}")
        for lang in failed: print(f"  {RED}✗{RESET} {lang}")
        if failed:
            sys.exit(1)
    else:
        lang = resolve_by_index(CONFIGS_RESUMES, target)
        if not _build_one(lang):
            sys.exit(1)


# ── watch ─────────────────────────────────────────────────────────────────────

def cmd_watch(target: str = "") -> None:
    if not target:
        cmd_list()
        target = prompt("Lang to watch (en, fa, #)")
        if not target:
            error("No choice made.")

    lang       = resolve_by_index(CONFIGS_RESUMES, target)
    resume_dir = RESUMES_DIR / lang

    log(f"Watch mode on resumes/{lang} — Ctrl+C to stop")
    _build_one(lang)

    watch_loop(
        watch_paths=[resume_dir],
        patterns=["*.tex"],
        rebuild_fn=lambda: _build_one(lang),
    )


# ── clean ─────────────────────────────────────────────────────────────────────

def cmd_clean(target: str = "") -> None:
    if target:
        lang = resolve_by_index(CONFIGS_RESUMES, target)
        log(f"Cleaning build artifacts for: {lang}")

        build_lang = BUILD_DIR / "resumes" / lang
        if build_lang.exists():
            shutil.rmtree(build_lang)

        conf_path = CONFIGS_RESUMES / f"{lang}.conf"
        if conf_path.exists():
            meta = load_conf(conf_path)
            out  = meta.get("OUTPUT_NAME", "")
            if out:
                pdf = BUILD_DIR / f"{out}.pdf"
                if pdf.exists():
                    pdf.unlink()

        resume_dir = RESUMES_DIR / lang
        if resume_dir.exists():
            clean_latex_artifacts(resume_dir)

        success(f"Cleaned {lang}")
    else:
        log("Cleaning all resume build artifacts…")
        build_resumes = BUILD_DIR / "resumes"
        if build_resumes.exists():
            shutil.rmtree(build_resumes)

        if RESUMES_DIR.exists():
            clean_latex_artifacts(RESUMES_DIR)

        for conf in list_conf_files(CONFIGS_RESUMES):
            meta = load_conf(conf)
            out  = meta.get("OUTPUT_NAME", "")
            if out:
                pdf = BUILD_DIR / f"{out}.pdf"
                if pdf.exists():
                    pdf.unlink()

        success("All resume artifacts cleaned")


# ── rename ────────────────────────────────────────────────────────────────────

def cmd_rename(target: str = "", new_name: str = "") -> None:
    if not target:
        cmd_list()
        target = prompt("Which resume to rename? (lang|#)")
        if not target:
            error("No choice made.")

    lang      = resolve_by_index(CONFIGS_RESUMES, target)
    conf_path = CONFIGS_RESUMES / f"{lang}.conf"
    meta      = load_conf(conf_path)
    current   = meta.get("OUTPUT_NAME", "resume")

    if not new_name:
        print()
        print(f"  {c('Current output name:')} {current}.pdf")
        print(f"  Enter new name {DIM}(without .pdf){RESET}:")
        new_name = prompt("New name")
        if not new_name:
            error("Name cannot be empty.")

    new_name = new_name.removesuffix(".pdf")

    text = conf_path.read_text(encoding="utf-8")
    if "OUTPUT_NAME=" in text:
        text = re.sub(r'^OUTPUT_NAME=.*$', f'OUTPUT_NAME="{new_name}"', text, flags=re.M)
    else:
        text += f'\nOUTPUT_NAME="{new_name}"\n'
    conf_path.write_text(text, encoding="utf-8")

    success(f"[{lang}] OUTPUT_NAME set to: {new_name}.pdf")
    info(f"Next build will produce: build/{new_name}.pdf")


# ── module class ──────────────────────────────────────────────────────────────

class ResumesModule(BaseModule):
    @property
    def name(self) -> str:
        return "Resumes"

    @property
    def script_name(self) -> str:
        return "resumes.py"

    @property
    def commands(self) -> dict:
        return {
            "list":   (cmd_list,   "                         List all resumes & build status"),
            "build":  (cmd_build,  "<lang|#|all>             Build resume(s) to PDF"),
            "watch":  (cmd_watch,  "<lang|#>                 Auto-rebuild on file change"),
            "rename": (cmd_rename, "<lang|#> [new-name]      Set output PDF name"),
            "clean":  (cmd_clean,  "[lang|#]                 Remove build artifacts"),
        }

    @property
    def menu_items(self) -> list[tuple]:
        return [
            ("1", "build",  "build     — Build a resume to PDF"),
            ("2", "all",    "build all — Build all resumes"),
            ("3", "watch",  "watch     — Watch mode (auto-rebuild)"),
            ("4", "rename", "rename    — Change output PDF name"),
            ("5", "clean",  "clean     — Remove build artifacts"),
            ("6", "list",   "list      — Show resume list"),
        ]

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

        # rename takes two optional positional args
        if cmd == "rename":
            cmd_rename(rest[0] if rest else "", rest[1] if len(rest) > 1 else "")
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


# ── entry point ───────────────────────────────────────────────────────────────

def main() -> None:
    ResumesModule().main()


if __name__ == "__main__":
    main()