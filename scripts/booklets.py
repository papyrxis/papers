#!/usr/bin/env python3
"""
Usage:
    python scripts/booklets.py                    # interactive menu
    python scripts/booklets.py <command> [args]   # direct command

Commands:
    new     <slug> [title]        Scaffold a new booklet (en + fa skeletons)
    build   <slug:lang|#|all>     Build booklet(s) to PDF
    watch   <slug:lang|#>         Auto-rebuild on file change
    list                          List all booklets & build status
    clean   [slug:lang|#]         Remove build artifacts
    help                          Show this help

A booklet has two independent editions, English and Persian, each driven
by its own config file:

    configs/booklets/<slug>-en.conf
    configs/booklets/<slug>-fa.conf

Target selectors accept "<slug>:<lang>" (e.g. "01-what-data-is...:fa"),
a bare numeric index into the combined list shown by `list`, or "all".

main.tex and meta.tex under booklets/<slug>/<lang>/ are GENERATED on every
build from booklets/templates/<lang>/ + the .conf file. They are never
hand-edited — edit the .conf, the chapters/, or the per-booklet
frontmatter/backmatter instead. Edit booklets/templates/<lang>/main.tex
only to change something ALL booklets in that language share.
"""

from __future__ import annotations

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
    clean_latex_artifacts, error, git_describe, hr, info,
    list_conf_files, load_conf, log, prompt, run_quiet,
    success, warn, watch_loop,
)

CONFIGS_BOOKLETS = ROOT / "configs" / "booklets"
BOOKLETS_DIR     = ROOT / "booklets"
TEMPLATES_DIR    = BOOKLETS_DIR / "templates"
SHARED_DIR       = BOOKLETS_DIR / "shared"
BOOKLET_CONFIGS  = BOOKLETS_DIR / "configs"
BUILD_DIR        = ROOT / "build"

LANGS = ("en", "fa")

LANG_ENGINE_DEFAULT = {"en": "pdflatex", "fa": "xelatex"}


# ── conf discovery: <slug>-<lang>.conf ──────────────────────────────────────

def _split_stem(stem: str) -> tuple[str, str] | None:
    """'01-foo-en' -> ('01-foo', 'en'); returns None if no known lang suffix."""
    for lang in LANGS:
        suffix = f"-{lang}"
        if stem.endswith(suffix):
            return stem[: -len(suffix)], lang
    return None


def _list_editions() -> list[tuple[str, str, Path]]:
    """All (slug, lang, conf_path), sorted by slug then lang."""
    out = []
    for conf in list_conf_files(CONFIGS_BOOKLETS):
        parsed = _split_stem(conf.stem)
        if parsed is None:
            warn(f"Skipping conf with unrecognized name: {conf.name}")
            continue
        slug, lang = parsed
        out.append((slug, lang, conf))
    return sorted(out, key=lambda t: (t[0], t[1]))


def _resolve_target(value: str) -> tuple[str, str]:
    """
    Resolve 'slug:lang', a bare numeric index (1-based, into _list_editions()),
    or a bare slug (only valid if exactly one edition exists for it).
    """
    editions = _list_editions()
    if not editions:
        error(f"No booklet configs found in {CONFIGS_BOOKLETS}")

    if value.isdigit():
        idx = int(value)
        if idx < 1 or idx > len(editions):
            error(f"No item at index {idx} (valid: 1-{len(editions)})")
        slug, lang, _ = editions[idx - 1]
        return slug, lang

    if ":" in value:
        slug, lang = value.split(":", 1)
        if lang not in LANGS:
            error(f"Unknown language '{lang}'. Valid: {', '.join(LANGS)}")
        if not (CONFIGS_BOOKLETS / f"{slug}-{lang}.conf").exists():
            error(f"No config for '{slug}:{lang}' "
                  f"(expected configs/booklets/{slug}-{lang}.conf)")
        return slug, lang

    matches = [(s, l) for s, l, _ in editions if s == value]
    if not matches:
        stems = sorted({s for s, _, _ in editions})
        error(
            f"Unknown booklet '{value}'.\n"
            f"  Valid slugs: {', '.join(stems)}\n"
            f"  Use 'slug:lang' (e.g. '{stems[0]}:en') or a number 1-{len(editions)}"
        )
    if len(matches) > 1:
        opts = ", ".join(f"{s}:{l}" for s, l in matches)
        error(f"'{value}' has multiple editions — specify one: {opts}")
    return matches[0]


# ── list ──────────────────────────────────────────────────────────────────────

def lang_desc(lang: str) -> str:
    return {
        "en": "English  — pdflatex",
        "fa": "فارسی    — xelatex, Vazirmatn, RTL",
    }.get(lang, "Unknown")


def cmd_list() -> None:
    print()
    print(f"  {BOLD}Booklets — Genix{RESET}")
    hr()
    print(f"  {'#':<4}  {'Slug:Lang':<48}  {'Built':<8}  Title")
    hr()

    for idx, (slug, lang, conf) in enumerate(_list_editions(), 1):
        meta  = load_conf(conf)
        out   = meta.get("OUTPUT_NAME", f"{slug}-{lang}")
        title = meta.get("BOOKLET_TITLE", "")

        built = (
            f"{GREEN}yes{RESET}"
            if (BUILD_DIR / "booklets" / f"{out}.pdf").exists()
            else f"{RED}no{RESET}"
        )

        label = f"{slug}:{lang}"
        short = title[:40] + ("…" if len(title) > 40 else "")
        print(f"  [{idx}]   {label:<48}  {built}       {short}")

    hr()
    print()
    print(f"  {c('Build one:')}   python scripts/booklets.py build <slug:lang|#>")
    print(f"  {c('Build all:')}   python scripts/booklets.py build all")
    print(f"  {c('New booklet:')} python scripts/booklets.py new <slug>")
    print()


# ── new ───────────────────────────────────────────────────────────────────────

def cmd_new(slug: str = "", title_en: str = "") -> None:
    if not slug:
        print()
        print(f"  {BOLD}New Booklet{RESET}")
        print()
        slug = prompt("Slug (e.g. 02-how-integers-work)")
        if not slug:
            error("Slug cannot be empty.")

    if not title_en:
        raw = re.sub(r'^[0-9]+-', '', slug)
        default_title = re.sub(r'-', ' ', raw).title()
        title_en = prompt("English title", default=default_title) or default_title

    year = datetime.now(timezone.utc).strftime("%Y")

    for lang in LANGS:
        booklet_lang_dir = BOOKLETS_DIR / slug / lang
        conf_path = CONFIGS_BOOKLETS / f"{slug}-{lang}.conf"

        if booklet_lang_dir.exists():
            error(f"Booklet directory already exists: booklets/{slug}/{lang}")
        if conf_path.exists():
            error(f"Config already exists: configs/booklets/{slug}-{lang}.conf")

        for sub in ("chapters", "frontmatter", "backmatter"):
            (booklet_lang_dir / sub).mkdir(parents=True, exist_ok=True)

    (BOOKLETS_DIR / slug / "references").mkdir(parents=True, exist_ok=True)
    CONFIGS_BOOKLETS.mkdir(parents=True, exist_ok=True)

    # ── en side ──────────────────────────────────────────────────────────────
    (CONFIGS_BOOKLETS / f"{slug}-en.conf").write_text(
        f"""\
BOOKLET_TITLE="{title_en}"
BOOKLET_TITLE_SHORT="{title_en[:20]}"
BOOKLET_SUBTITLE="Extracted from Arliz, Volume I --- Zero to Bit"
BOOKLET_AUTHOR="Mahdi Mamashli"
BOOKLET_AUTHOR_HANDLE="Genix"
BOOKLET_EMAIL="bitsgenix@gmail.com"
BOOKLET_YEAR="{year}"

PDF_TITLE="{title_en}"
PDF_AUTHOR="Mahdi Mamashli"
PDF_SUBJECT="topic one, topic two, topic three"
PDF_KEYWORDS="keyword1, keyword2, keyword3, Arliz"

OUTPUT_NAME="Mamashli-{slug}-EN"
ENGINE="pdflatex"
BIBTEX="biber"
# Optional: point at this booklet's own bib. If unset, falls back to
# booklets/shared/en/backmatter/default.bib
BIB_FILE="../references/paper.bib"

CHAPTERS=(
  "chapters/chapter01"
)
""",
        encoding="utf-8",
    )

    (BOOKLETS_DIR / slug / "en" / "frontmatter" / "preface.tex").write_text(
        "\\chapter*{Preface}\n"
        "\\addcontentsline{toc}{chapter}{Preface}\n\n"
        "Write this booklet's preface here.\n",
        encoding="utf-8",
    )
    (BOOKLETS_DIR / slug / "en" / "backmatter" / "note.tex").write_text(
        "\\chapter*{A Note on This Booklet}\n"
        "\\addcontentsline{toc}{chapter}{A Note on This Booklet}\n\n"
        "Write this booklet's closing note here.\n",
        encoding="utf-8",
    )
    (BOOKLETS_DIR / slug / "en" / "chapters" / "chapter01.tex").write_text(
        "\\chapter{Chapter Title}\n\\label{ch:chapter01}\n\nWrite the chapter here.\n",
        encoding="utf-8",
    )

    # ── fa side ──────────────────────────────────────────────────────────────
    (CONFIGS_BOOKLETS / f"{slug}-fa.conf").write_text(
        f"""\
# configs/booklets/{slug}-fa.conf
BOOKLET_TITLE="عنوان کتابچه را اینجا بنویس"
BOOKLET_TITLE_SHORT="عنوان کوتاه"
BOOKLET_SUBTITLE="برگرفته از آرلیز، جلد یک --- صفر تا بیت"
BOOKLET_AUTHOR="مهدی ممشلی"
BOOKLET_AUTHOR_HANDLE="Genix"
BOOKLET_EMAIL="bitsgenix@gmail.com"
BOOKLET_YEAR="{year}"

PDF_TITLE="{title_en}"
PDF_AUTHOR="Mahdi Mamashli"
PDF_SUBJECT="topic one, topic two, topic three"
PDF_KEYWORDS="keyword1, keyword2, keyword3, Arliz"

OUTPUT_NAME="Mamashli-{slug}-FA"
ENGINE="xelatex"
BIBTEX="biber"
# Optional: point at this booklet's own bib. If unset, falls back to
# booklets/shared/fa/backmatter/default.bib
BIB_FILE="../references/paper.bib"

CHAPTERS=(
  "chapters/chapter01"
)
""",
        encoding="utf-8",
    )

    (BOOKLETS_DIR / slug / "fa" / "frontmatter" / "preface.tex").write_text(
        "\\chapter*{پیش‌گفتار}\n"
        "\\addcontentsline{toc}{chapter}{پیش‌گفتار}\n\n"
        "پیش‌گفتار این کتابچه را اینجا بنویس.\n",
        encoding="utf-8",
    )
    (BOOKLETS_DIR / slug / "fa" / "backmatter" / "note.tex").write_text(
        "\\chapter*{یادداشتی درباره‌ی این کتابچه}\n"
        "\\addcontentsline{toc}{chapter}{یادداشتی درباره‌ی این کتابچه}\n\n"
        "یادداشت پایانی این کتابچه را اینجا بنویس.\n",
        encoding="utf-8",
    )
    (BOOKLETS_DIR / slug / "fa" / "chapters" / "chapter01.tex").write_text(
        "\\chapter{عنوان فصل}\n\\label{ch:chapter01}\n\nمتن فصل را اینجا بنویس.\n",
        encoding="utf-8",
    )

    (BOOKLETS_DIR / slug / "references" / "paper.bib").write_text(
        "% BibTeX references for this booklet.\n", encoding="utf-8"
    )

    print()
    success(f"Scaffolded: booklets/{slug} (en + fa)")
    print()
    print(f"  {c('Next steps:')}")
    print(f"    1. Write chapters:      booklets/{slug}/{{en,fa}}/chapters/*.tex")
    print(f"    2. Write preface/note:  booklets/{slug}/{{en,fa}}/{{frontmatter,backmatter}}/")
    print(f"    3. Add references:      booklets/{slug}/references/paper.bib")
    print(f"    4. List chapter files:  configs/booklets/{slug}-{{en,fa}}.conf (CHAPTERS array)")
    print(f"    5. Build:               python scripts/booklets.py build {slug}:en")
    print()


# ── generate main.tex + meta.tex ─────────────────────────────────────────────

def _resolve_bib_path(meta: dict, lang: str, booklet_lang_dir: Path) -> str:
    """
    Return the @BIB_PATH@ value, relative to booklet_lang_dir (the cwd at
    build time). Falls back to the shared default bib if BIB_FILE is unset
    or the file it points to doesn't exist.
    """
    bib_file = meta.get("BIB_FILE", "").strip()
    if bib_file:
        candidate = (booklet_lang_dir / bib_file).resolve()
        if candidate.is_file():
            return bib_file
        warn(f"BIB_FILE '{bib_file}' not found relative to {booklet_lang_dir} "
             f"— falling back to shared default.bib")
    return f"../../shared/{lang}/backmatter/default.bib"


def _generate_booklet_tex(slug: str, lang: str) -> None:
    conf_path = CONFIGS_BOOKLETS / f"{slug}-{lang}.conf"
    booklet_lang_dir = BOOKLETS_DIR / slug / lang
    tpl_main = TEMPLATES_DIR / lang / "main.tex"
    tpl_meta = TEMPLATES_DIR / lang / "meta.tex"

    if not conf_path.exists():
        error(f"No config for '{slug}:{lang}' (expected {conf_path})")
    if not tpl_main.exists() or not tpl_meta.exists():
        error(f"Templates missing for lang '{lang}' under {TEMPLATES_DIR / lang}")
    if not booklet_lang_dir.exists():
        error(f"Booklet directory not found: {booklet_lang_dir}")

    meta = load_conf(conf_path)
    for key in ("BOOKLET_TITLE", "CHAPTERS"):
        if not meta.get(key):
            error(f"{key} not set in {conf_path}")

    year = meta.get("BOOKLET_YEAR", datetime.now(timezone.utc).strftime("%Y"))
    bib_path = _resolve_bib_path(meta, lang, booklet_lang_dir)

    # ── meta.tex ─────────────────────────────────────────────────────────────
    meta_replacements = {
        "@BOOKLET_TITLE@":       meta.get("BOOKLET_TITLE", ""),
        "@BOOKLET_TITLE_SHORT@": meta.get("BOOKLET_TITLE_SHORT",
                                           meta.get("BOOKLET_TITLE", "")[:20]),
        "@BOOKLET_SUBTITLE@":    meta.get("BOOKLET_SUBTITLE", ""),
        "@BOOKLET_AUTHOR@":      meta.get("BOOKLET_AUTHOR", "Mahdi Mamashli"),
        "@BOOKLET_AUTHOR_HANDLE@": meta.get("BOOKLET_AUTHOR_HANDLE", "Genix"),
        "@BOOKLET_EMAIL@":       meta.get("BOOKLET_EMAIL", "bitsgenix@gmail.com"),
        "@BOOKLET_YEAR@":        year,
        "@PDF_TITLE@":           meta.get("PDF_TITLE", meta.get("BOOKLET_TITLE", "")),
        "@PDF_AUTHOR@":          meta.get("PDF_AUTHOR", "Mahdi Mamashli"),
        "@PDF_SUBJECT@":         meta.get("PDF_SUBJECT", ""),
        "@PDF_KEYWORDS@":        meta.get("PDF_KEYWORDS", ""),
    }
    meta_tpl_text = tpl_meta.read_text(encoding="utf-8")
    for token, value in meta_replacements.items():
        meta_tpl_text = meta_tpl_text.replace(token, value)
    (booklet_lang_dir / "meta.tex").write_text(meta_tpl_text, encoding="utf-8")

    # ── main.tex ─────────────────────────────────────────────────────────────
    chapters_block = "\n".join(
        f"\\input{{{ch}}}" for ch in meta.get("CHAPTERS", [])
    ) + "\n"

    main_replacements = {
        "@CONFIGS_PATH@":          "../../../configs",
        "@BOOKLETS_CONFIGS_PATH@": "../../configs",
        "@SHARED_PATH@":           "../../shared",
        "@BIB_PATH@":              bib_path,
    }
    main_tpl_text = tpl_main.read_text(encoding="utf-8")
    lines_out: list[str] = []
    for line in main_tpl_text.splitlines():
        if "@CHAPTERS@" in line:
            lines_out.append(chapters_block.rstrip("\n"))
        else:
            for token, value in main_replacements.items():
                line = line.replace(token, value)
            lines_out.append(line)

    (booklet_lang_dir / "main.tex").write_text(
        "\n".join(lines_out) + "\n", encoding="utf-8"
    )


# ── build ─────────────────────────────────────────────────────────────────────

def _build_one_edition(slug: str, lang: str) -> bool:
    conf_path = CONFIGS_BOOKLETS / f"{slug}-{lang}.conf"
    booklet_lang_dir = BOOKLETS_DIR / slug / lang

    if not conf_path.exists():
        warn(f"Unknown booklet '{slug}:{lang}' (no {conf_path})")
        return False
    if not booklet_lang_dir.exists():
        warn(f"Booklet directory not found: {booklet_lang_dir}")
        return False

    log(f"[{slug}:{lang}] generate main.tex + meta.tex")
    _generate_booklet_tex(slug, lang)

    meta   = load_conf(conf_path)
    engine = meta.get("ENGINE", LANG_ENGINE_DEFAULT.get(lang, "pdflatex"))
    bibtex = meta.get("BIBTEX", "biber")
    out    = meta.get("OUTPUT_NAME", f"{slug}-{lang}")

    log(f"[{slug}:{lang}] compile ({engine}, passes + {bibtex})")
    out_dir = BUILD_DIR / "booklets" / slug / lang
    out_dir.mkdir(parents=True, exist_ok=True)

    env = {
        "PROJECT_VERSION": git_describe(ROOT),
        "BUILD_DATE":      datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
    }

    def compile_pass() -> int:
        rc, _, _ = run_quiet(
            [engine, "-interaction=nonstopmode",
             f"-output-directory={out_dir}", "main.tex"],
            cwd=booklet_lang_dir, env=env,
        )
        return rc

    compile_pass()
    if not (out_dir / "main.pdf").exists():
        warn(f"[{slug}:{lang}] {engine} pass 1 failed — see {out_dir / 'main.log'}")
        return False

    main_tex_content = (booklet_lang_dir / "main.tex").read_text(encoding="utf-8")
    if "\\addbibresource" in main_tex_content or "\\printbibliography" in main_tex_content:
        bcf = out_dir / "main.bcf"
        if bcf.exists():
            run_quiet([bibtex, str(out_dir / "main")], cwd=booklet_lang_dir, env=env)
            compile_pass()

    compile_pass()

    src = out_dir / "main.pdf"
    dst = BUILD_DIR / "booklets" / f"{out}.pdf"

    if not src.exists():
        warn(f"[{slug}:{lang}] build finished but {src} not found "
             f"— check {out_dir / 'main.log'}")
        return False

    shutil.copy2(src, dst)
    success(f"[{slug}:{lang}] done → build/booklets/{out}.pdf")
    return True


def cmd_build(target: str = "") -> None:
    if not target:
        print()
        print(f"  {BOLD}Build Booklet{RESET}")
        print()
        cmd_list()
        target = prompt("Which booklet? (slug:lang, #, or 'all')")
        if not target:
            error("No choice made.")

    if target == "all":
        passed, failed = [], []
        for slug, lang, _ in _list_editions():
            if _build_one_edition(slug, lang):
                passed.append(f"{slug}:{lang}")
            else:
                failed.append(f"{slug}:{lang}")
        print()
        success(f"Build summary: {len(passed)} passed, {len(failed)} failed")
        for e in passed: print(f"  {GREEN}✓{RESET} {e}")
        for e in failed: print(f"  {RED}✗{RESET} {e}")
        if failed:
            sys.exit(1)
    else:
        slug, lang = _resolve_target(target)
        if not _build_one_edition(slug, lang):
            sys.exit(1)


# ── watch ─────────────────────────────────────────────────────────────────────

def cmd_watch(target: str = "") -> None:
    if not target:
        cmd_list()
        target = prompt("Which booklet to watch? (slug:lang, #)")
        if not target:
            error("No choice made.")

    slug, lang = _resolve_target(target)
    booklet_lang_dir = BOOKLETS_DIR / slug / lang
    conf_path = CONFIGS_BOOKLETS / f"{slug}-{lang}.conf"

    log(f"Watch mode on booklets/{slug}/{lang} — Ctrl+C to stop")
    _build_one_edition(slug, lang)

    watch_loop(
        watch_paths=[booklet_lang_dir, BOOKLETS_DIR / slug / "references", conf_path],
        patterns=["*.tex", "*.bib", "*.conf"],
        rebuild_fn=lambda: _build_one_edition(slug, lang),
    )


# ── clean ─────────────────────────────────────────────────────────────────────

def cmd_clean(target: str = "") -> None:
    if target:
        slug, lang = _resolve_target(target)
        log(f"Cleaning build artifacts for: {slug}:{lang}")

        out_dir = BUILD_DIR / "booklets" / slug / lang
        if out_dir.exists():
            shutil.rmtree(out_dir)

        booklet_lang_dir = BOOKLETS_DIR / slug / lang
        if booklet_lang_dir.exists():
            clean_latex_artifacts(booklet_lang_dir)

        conf_path = CONFIGS_BOOKLETS / f"{slug}-{lang}.conf"
        if conf_path.exists():
            meta = load_conf(conf_path)
            out  = meta.get("OUTPUT_NAME", "")
            if out:
                pdf = BUILD_DIR / "booklets" / f"{out}.pdf"
                if pdf.exists():
                    pdf.unlink()

        success(f"Cleaned {slug}:{lang}")
    else:
        log("Cleaning all booklet build artifacts…")
        build_booklets = BUILD_DIR / "booklets"
        if build_booklets.exists():
            shutil.rmtree(build_booklets)

        if BOOKLETS_DIR.exists():
            clean_latex_artifacts(BOOKLETS_DIR)

        success("All booklet artifacts cleaned")


# ── module class ──────────────────────────────────────────────────────────────

class BookletsModule(BaseModule):
    @property
    def name(self) -> str:
        return "Booklets"

    @property
    def script_name(self) -> str:
        return "booklets.py"

    @property
    def commands(self) -> dict:
        return {
            "list":  (cmd_list,  "                         List all booklets & build status"),
            "new":   (cmd_new,   "<slug> [title]           Scaffold a new booklet (en + fa)"),
            "build": (cmd_build, "<slug:lang|#|all>        Build booklet(s) to PDF"),
            "watch": (cmd_watch, "<slug:lang|#>            Auto-rebuild on file change"),
            "clean": (cmd_clean, "[slug:lang|#]            Remove build artifacts"),
        }

    @property
    def menu_items(self) -> list[tuple]:
        return [
            ("1", "build", "build     — Build a booklet edition to PDF"),
            ("2", "all",   "build all — Build all booklet editions"),
            ("3", "watch", "watch     — Watch mode (auto-rebuild)"),
            ("4", "new",   "new       — Scaffold a new booklet"),
            ("5", "clean", "clean     — Remove build artifacts"),
            ("6", "list",  "list      — Show booklet list"),
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
    BookletsModule().main()


if __name__ == "__main__":
    main()
