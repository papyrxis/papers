#!/usr/bin/env python3
"""
Usage:
    python scripts/papers.py                    # interactive menu
    python scripts/papers.py <command> [args]   # direct command

Commands:
    new     <slug> [style]       Scaffold a new paper
    build   <slug|#|all>         Build paper(s) to PDF
    export  <slug|#|all> [tgt…]  Export paper(s) to Markdown
    watch   <slug|#>             Auto-rebuild on file change
    list                         List all papers
    styles                       Show available styles
    clean   [slug|#]             Remove build artifacts
    delete  <slug|#>             Delete a paper completely
    help                         Show this help
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
    BOLD, CYAN, DIM, GREEN, RED, RESET, YELLOW, BLUE, GREY,
    BaseModule,
    b, c,
    clean_latex_artifacts, confirm, confirm_slug,
    error, git_describe, hr, info, list_conf_files,
    load_conf, log, prompt, resolve_by_index, run, run_quiet,
    success, warn, watch_loop,
)

CONFIGS_PAPERS = ROOT / "configs" / "papers"
PAPERS_DIR     = ROOT / "papers"
BUILD_DIR      = ROOT / "build"
TARGETS_DIR    = SCRIPT_DIR / "lib" / "targets"
CSL_DIR        = SCRIPT_DIR / "lib" / "csl"
LUA_FILTER     = SCRIPT_DIR / "lib" / "clean-export.lua"

STYLES = ("personal", "single-column", "two-column", "academic", "ieee", "journal")

RELEASE_BASE_URL = "https://github.com/papyrxis/papers/releases/download/latest-pre-release"


# ── style helpers ─────────────────────────────────────────────────────────────

def style_desc(style: str) -> str:
    return {
        "personal":      "Personal essay / technical note (Charter, branded footer)",
        "single-column": "Clean single-column (Charter, minimal chrome)",
        "two-column":    "Two-column general layout (Charter, accent header)",
        "academic":      "Formal research paper (Times, theorems, author footer, TOC)",
        "ieee":          "IEEE conference format (Times, two-column, uppercase sections)",
        "journal":       "Journal submission (Palatino, running header, full footer, TOC)",
    }.get(style, "Unknown style")


# ── list ──────────────────────────────────────────────────────────────────────

def cmd_list() -> None:
    print()
    print(f"  {BOLD}Papers — Genix{RESET}")
    hr()
    print(f"  {'Slug':<46} {'Style':<14} {'Built':<6}  Title")
    hr()

    confs = list_conf_files(CONFIGS_PAPERS)
    for conf in confs:
        slug  = conf.stem
        meta  = load_conf(conf)
        style = meta.get("PAPER_STYLE", "—")
        title = meta.get("PAPER_TITLE", "")

        safe_title = re.sub(r'[^A-Za-z0-9_-]', '', title.replace(" ", "_"))
        hits = list(BUILD_DIR.glob(f"*{safe_title}*.pdf")) if safe_title else []
        if hits:
            built = f"{GREEN}yes{RESET}"
        elif list(BUILD_DIR.glob("*.pdf")):
            built = f"{YELLOW}stale{RESET}"
        else:
            built = f"{RED}no{RESET}"

        short = title[:50] + ("…" if len(title) > 50 else "")
        print(f"  {slug:<46} {style:<14} {built}  {short}")

    hr()
    print(f"  {len(confs)} paper(s) total")
    print()
    print(f"  {c('Build one:')}   make paper PAPER=<slug>")
    print(f"  {c('Build all:')}   make build")
    print(f"  {c('New paper:')}   make new-paper SLUG=<slug> STYLE=<style>")
    print()


# ── styles ────────────────────────────────────────────────────────────────────

def cmd_styles() -> None:
    print()
    print(f"  {BOLD}Available Paper Styles{RESET}")
    hr()
    for s in STYLES:
        print(f"  {CYAN}{s:<16}{RESET} {style_desc(s)}")
    print()
    print(f"  Use: {DIM}make new-paper SLUG=<slug> STYLE=<style>{RESET}")
    print()


# ── new ───────────────────────────────────────────────────────────────────────

def cmd_new(slug: str = "", style: str = "") -> None:
    if not slug:
        print()
        print(f"  {BOLD}New Paper{RESET}")
        print()
        slug = prompt("Slug (e.g. 02-my-paper-title)")
        if not slug:
            error("Slug cannot be empty.")

    if not style:
        print()
        print(f"  {CYAN}Available styles:{RESET}")
        for s in STYLES:
            print(f"    {s:<16} {style_desc(s)}")
        print()
        style = prompt("Style", default="personal")

    if style not in STYLES:
        error(f"Unknown style '{style}'. Valid: {' | '.join(STYLES)}")

    _scaffold_paper(slug, style)


def _scaffold_paper(slug: str, style: str) -> None:
    paper_dir = PAPERS_DIR / slug
    conf_path = CONFIGS_PAPERS / f"{slug}.conf"

    if paper_dir.exists():
        error(f"Paper already exists: papers/{slug}")
    if conf_path.exists():
        error(f"Config already exists: configs/papers/{slug}.conf")

    raw   = re.sub(r'^[0-9]+-', '', slug)
    title = re.sub(r'-', ' ', raw).title()
    year  = datetime.now(timezone.utc).strftime("%Y")
    toc   = "true" if style in ("academic", "journal") else "false"

    log(f"Scaffolding: papers/{slug}")
    log(f"Style:       {style}")
    log(f"Title:       {title}")

    for sub in ("sections", "figures", "references", "frontmatter", "backmatter"):
        (paper_dir / sub).mkdir(parents=True, exist_ok=True)
    CONFIGS_PAPERS.mkdir(parents=True, exist_ok=True)

    conf_path.write_text(
        f"""\
# configs/papers/{slug}.conf — metadata for this paper

PAPER_TITLE="{title}"
PAPER_AUTHOR="Mahdi Mamashli (Genix)"
PAPER_EMAIL="bitsgenix@gmail.com"
PAPER_STYLE="{style}"
PAPER_YEAR="{year}"
PAPER_FONTSIZE="12pt"

PDF_TITLE="{title}"
PDF_SUBJECT=""
PDF_KEYWORDS=""

BIB_FILE="references/paper.bib"
TOC="{toc}"

ENGINE="pdflatex"
BIBTEX="biber"

SECTIONS=(
  "sections/01-introduction"
  "sections/02-background"
  "sections/03-approach"
  "sections/04-analysis"
  "sections/05-conclusion"
)

BACKMATTER=(
  "backmatter/bibliography"
)
""",
        encoding="utf-8",
    )

    (paper_dir / "frontmatter" / "abstract.tex").write_text(
        """\
% frontmatter/abstract.tex

\\begin{abstract}
Write a concise abstract here.
\\end{abstract}

\\paragraph{Keywords} keyword one; keyword two; keyword three.
""",
        encoding="utf-8",
    )

    (paper_dir / "backmatter" / "bibliography.tex").write_text(
        """\
% backmatter/bibliography.tex
\\appendix
\\section*{Bibliography}
\\addcontentsline{toc}{section}{Bibliography}
\\printbibliography[heading=none]
""",
        encoding="utf-8",
    )

    stubs = {
        "01-introduction": ("Introduction", "intro",
                            "State the problem plainly. Why does it matter?"),
        "02-background":   ("Background",   "background",
                            "Cover the prior work and concepts the reader needs."),
        "03-approach":     ("Approach",     "approach",
                            "Describe the argument or method precisely."),
        "04-analysis":     ("Analysis",     "analysis",
                            "Work through the evidence, proof, or results."),
        "05-conclusion":   ("Conclusion",   "conclusion",
                            "One paragraph: problem, approach, finding, future work."),
    }
    for fname, (sec, label, hint) in stubs.items():
        (paper_dir / "sections" / f"{fname}.tex").write_text(
            f"\\section{{{sec}}}\n\\label{{sec:{label}}}\n\n{hint}\n",
            encoding="utf-8",
        )

    (paper_dir / "references" / "paper.bib").write_text(
        """\
% BibTeX references for this paper.

@article{example2024,
  author  = {Last, First},
  title   = {A Title That Matters},
  journal = {Journal of Important Things},
  year    = {2024},
  volume  = {1},
  number  = {1},
  pages   = {1--10},
  doi     = {10.0000/example},
}
""",
        encoding="utf-8",
    )

    (paper_dir / "figures" / "README.md").write_text(
        """\
# Figures

Place all figures for this paper here. Supported formats: PDF, PNG, EPS.
""",
        encoding="utf-8",
    )

    _generate_main_tex(slug)
    _update_papers_list()

    print()
    success(f"Scaffolded: papers/{slug}")
    print()
    print(f"  {c('Style:')}   {style}")
    print(f"  {c('Title:')}   {title}")
    print()
    print(f"  {c('Next steps:')}")
    print(f"    1. Write the abstract:  papers/{slug}/frontmatter/abstract.tex")
    print(f"    2. Write sections:      papers/{slug}/sections/*.tex")
    print(f"    3. Add references:      papers/{slug}/references/paper.bib")
    print(f"    4. Build the PDF:       make paper PAPER={slug}")
    print()


# ── generate main.tex ─────────────────────────────────────────────────────────

def _generate_main_tex(slug: str) -> None:
    conf_path = CONFIGS_PAPERS / f"{slug}.conf"
    paper_dir = PAPERS_DIR / slug
    template  = ROOT / "main.tex"

    if not conf_path.exists():
        error(f"No config for paper '{slug}' (expected {conf_path})")
    if not template.exists():
        error(f"Template not found ({template})")
    if not paper_dir.exists():
        error(f"Paper directory not found ({paper_dir})")

    meta = load_conf(conf_path)

    for key in ("PAPER_TITLE", "PAPER_STYLE", "SECTIONS"):
        if not meta.get(key):
            error(f"{key} not set in {conf_path}")

    if meta["PAPER_STYLE"] not in STYLES:
        error(
            f"Unknown PAPER_STYLE '{meta['PAPER_STYLE']}'."
            f" Valid: {' | '.join(STYLES)}"
        )

    year = meta.get("PAPER_YEAR", datetime.now(timezone.utc).strftime("%Y"))

    sections_block  = "\n\n".join(
        f"\\input{{{s}}}" for s in meta.get("SECTIONS", [])
    ) + "\n\n"
    backmatter_list  = meta.get("BACKMATTER", ["backmatter/bibliography"])
    backmatter_block = "\n".join(f"\\input{{{b}}}" for b in backmatter_list) + "\n"
    toc_block = (
        "\\tableofcontents\n\\newpage\n"
        if meta.get("TOC", "false").lower() == "true"
        else ""
    )

    replacements = {
        "@PAPER_TITLE@":    meta.get("PAPER_TITLE", ""),
        "@PAPER_AUTHOR@":   meta.get("PAPER_AUTHOR", "Mahdi Mamashli (Genix)"),
        "@PAPER_EMAIL@":    meta.get("PAPER_EMAIL", "bitsgenix@gmail.com"),
        "@PAPER_STYLE@":    meta["PAPER_STYLE"],
        "@PAPER_YEAR@":     year,
        "@PAPER_FONTSIZE@": meta.get("PAPER_FONTSIZE", "12pt"),
        "@PDF_TITLE@":      meta.get("PDF_TITLE", meta.get("PAPER_TITLE", "")),
        "@PDF_SUBJECT@":    meta.get("PDF_SUBJECT", ""),
        "@PDF_KEYWORDS@":   meta.get("PDF_KEYWORDS", ""),
        "@BIB_PATH@":       meta.get("BIB_FILE", "references/paper.bib"),
        "@PXIS_PATH@":      "../../.pxis",
        "@CONFIGS_PATH@":   "../../configs",
    }

    tpl = template.read_text(encoding="utf-8")
    lines_out: list[str] = []
    for line in tpl.splitlines():
        if "@SECTIONS@" in line:
            lines_out.append(sections_block)
        elif "@BACKMATTER@" in line:
            lines_out.append(backmatter_block)
        elif "@TOCBLOCK@" in line:
            lines_out.append(toc_block)
        else:
            for token, value in replacements.items():
                line = line.replace(token, value)
            lines_out.append(line)

    output = paper_dir / "main.tex"
    output.write_text("\n".join(lines_out) + "\n", encoding="utf-8")
    print(f"generated {output.relative_to(ROOT)}")


# ── build ─────────────────────────────────────────────────────────────────────

def _ensure_pxis() -> None:
    if not (ROOT / ".pxis" / "preset.tex").exists():
        warn(".pxis/preset.tex missing — running sync…")
        workspace = ROOT / "workspace"
        if (workspace / "src" / "sync.sh").exists():
            run(["bash", str(workspace / "src" / "sync.sh")])
        else:
            error(
                ".pxis/preset.tex missing and no workspace/ submodule found. "
                "Run: make sync"
            )


def _build_one_paper(slug: str) -> bool:
    conf_path = CONFIGS_PAPERS / f"{slug}.conf"
    paper_dir = PAPERS_DIR / slug

    if not conf_path.exists():
        warn(f"Unknown paper '{slug}' (no {conf_path})")
        return False
    if not paper_dir.exists():
        warn(f"Paper directory not found: {paper_dir}")
        return False

    log(f"[{slug}] generate main.tex")
    _generate_main_tex(slug)

    meta   = load_conf(conf_path)
    engine = meta.get("ENGINE", "pdflatex")
    bibtex = meta.get("BIBTEX", "biber")

    log(f"[{slug}] compile ({engine}, 2 passes + {bibtex})")
    out_dir = BUILD_DIR / slug
    out_dir.mkdir(parents=True, exist_ok=True)

    env = {
        "TEXINPUTS":       f".:{paper_dir}:{ROOT}:{ROOT / 'workspace'}::",
        "PROJECT_VERSION": git_describe(ROOT),
        "BUILD_DATE":      datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
    }

    def compile_pass() -> int:
        rc, _, _ = run_quiet(
            [engine, "-interaction=nonstopmode",
             f"-output-directory={out_dir}", "main.tex"],
            cwd=paper_dir, env=env,
        )
        return rc

    compile_pass()
    if not (out_dir / "main.pdf").exists():
        print()
        error(
            f"[{slug}] {engine} pass 1 failed — "
            f"see {out_dir / 'main.log'}"
        )
        
    main_tex_content = (paper_dir / "main.tex").read_text(encoding="utf-8")
    if "\\addbibresource" in main_tex_content or "\\printbibliography" in main_tex_content:
        bcf = out_dir / "main.bcf"
        if not bcf.exists():
            error(f"[{slug}] main.bcf not found after pass 1 — see {out_dir / 'main.log'}")
        run_quiet([bibtex, str(out_dir / "main")], cwd=paper_dir, env=env)
        compile_pass()

    compile_pass()

    year       = datetime.now(timezone.utc).strftime("%Y")
    title      = meta.get("PAPER_TITLE", slug)
    safe_title = re.sub(r'[^A-Za-z0-9_-]', '', title.replace(" ", "_"))
    out_name   = f"{year}_Genix_{safe_title}.pdf"
    src        = out_dir / "main.pdf"
    dst        = BUILD_DIR / out_name

    if not src.exists():
        error(f"[{slug}] build finished but {src} not found — check {out_dir / 'main.log'}")

    shutil.copy2(src, dst)
    success(f"[{slug}] done → build/{out_name}")
    return True


def cmd_build(target: str = "") -> None:
    _ensure_pxis()

    if not target:
        print()
        print(f"  {BOLD}Build Paper{RESET}")
        print()
        cmd_list()
        target = prompt("Slug to build (or 'all')")
        if not target:
            error("Slug cannot be empty.")

    if target == "all":
        passed, failed = [], []
        for conf in list_conf_files(CONFIGS_PAPERS):
            slug = conf.stem
            if _build_one_paper(slug):
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
        slug = resolve_by_index(CONFIGS_PAPERS, target)
        _build_one_paper(slug)


# ── watch ─────────────────────────────────────────────────────────────────────

def cmd_watch(slug_input: str = "") -> None:
    _ensure_pxis()
    if not slug_input:
        cmd_list()
        slug_input = prompt("Slug to watch")
        if not slug_input:
            error("Slug cannot be empty.")

    slug      = resolve_by_index(CONFIGS_PAPERS, slug_input)
    paper_dir = PAPERS_DIR / slug

    log(f"Watch mode on papers/{slug} — Ctrl+C to stop")
    _build_one_paper(slug)

    watch_loop(
        watch_paths=[paper_dir, CONFIGS_PAPERS / f"{slug}.conf"],
        patterns=["*.tex", "*.bib", "*.conf"],
        rebuild_fn=lambda: _build_one_paper(slug),
    )


# ── clean ─────────────────────────────────────────────────────────────────────

def cmd_clean(slug_input: str = "") -> None:
    if slug_input:
        slug = resolve_by_index(CONFIGS_PAPERS, slug_input)
        log(f"Cleaning build artifacts for: {slug}")

        build_slug = BUILD_DIR / slug
        if build_slug.exists():
            shutil.rmtree(build_slug)

        paper_dir = PAPERS_DIR / slug
        if paper_dir.exists():
            clean_latex_artifacts(paper_dir)

        meta  = load_conf(CONFIGS_PAPERS / f"{slug}.conf")
        title = meta.get("PAPER_TITLE", slug)
        safe  = re.sub(r'[^A-Za-z0-9_-]', '', title.replace(" ", "_"))
        for f in BUILD_DIR.glob(f"*{safe}*.pdf"):
            f.unlink()

        success(f"Cleaned {slug}")
    else:
        log("Cleaning all build artifacts…")

        for conf in list_conf_files(CONFIGS_PAPERS):
            gen = PAPERS_DIR / conf.stem / "main.tex"
            if gen.exists():
                try:
                    first_lines = gen.read_text(encoding="utf-8")[:200]
                    if "inherited template" in first_lines:
                        gen.unlink()
                        print(f"  removed {gen.relative_to(ROOT)}")
                except OSError:
                    pass

        if BUILD_DIR.exists():
            shutil.rmtree(BUILD_DIR)
            print("  removed build/")

        clean_latex_artifacts(PAPERS_DIR)
        success("All clean")


# ── export ────────────────────────────────────────────────────────────────────

def _load_target_conf(target: str) -> dict:
    """Parse a *.target.sh file into a dict of variables."""
    tfile = TARGETS_DIR / f"{target}.target.sh"
    if not tfile.exists():
        error(f"Unknown target '{target}' (no {tfile})")
    raw = tfile.read_text(encoding="utf-8")

    conf: dict = {
        "TARGET_LABEL":           target,
        "CSL_FILE":               "ieee.csl",
        "REFERENCES_HEADING":     "References",
        "REFERENCES_NUMBERED":    "0",
        "OUTPUT_EXT":             "md",
        "FRONT_MATTER_TEMPLATE":  "",
        "FRONT_MATTER_COMMENTED": "0",
        "INCLUDE_H1_TITLE":       "1",
        "INCLUDE_BYLINE":         "1",
        "EXTRA_LUA_FILTER":       "",
    }

    for line in raw.splitlines():
        line = line.strip()
        if line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        key = key.strip()
        if key not in conf:
            continue
        val = val.strip()
        if val.startswith('"') and val.endswith('"'):
            val = val[1:-1]
        elif val.startswith("'") and val.endswith("'"):
            val = val[1:-1]
        if "$" in val:
            val = ""
        conf[key] = val

    return conf


def _flatten_tex(paper_dir: Path, out_file: Path, root: Path) -> tuple[str, str]:
    """Inline \\input{} references from main.tex and return (title, author)."""

    def strip_comments(s: str) -> str:
        out = []
        for line in s.split("\n"):
            i = 0
            idx = None
            while i < len(line):
                if line[i] == "%" and (i == 0 or line[i - 1] != "\\"):
                    idx = i
                    break
                i += 1
            out.append(line[:idx] if idx is not None else line)
        return "\n".join(out)

    def resolve_inputs(text: str, base_dir: Path, depth: int = 0) -> str:
        if depth > 12:
            return text

        def repl(m: re.Match) -> str:
            rel = m.group(1).strip()
            for candidate in [
                base_dir / rel, base_dir / f"{rel}.tex",
                paper_dir / rel, paper_dir / f"{rel}.tex",
                root / rel,      root / f"{rel}.tex",
            ]:
                if candidate.is_file():
                    inner = candidate.read_text(encoding="utf-8", errors="replace")
                    return resolve_inputs(inner, candidate.parent, depth + 1)
            return ""

        return re.sub(r'\\input\{([^}]+)\}', repl, text)

    def clean_author(s: str) -> str:
        s = s.replace("\\\\", "\n")
        s = re.sub(r'\\(?:small|large|Large|texttt|textit|textbf|emph)\s*', '', s)
        s = s.replace("{", "").replace("}", "")
        lines = [ln.strip() for ln in s.split("\n") if ln.strip()]
        return " — ".join(lines).strip()

    main_tex = (paper_dir / "main.tex").read_text(encoding="utf-8", errors="replace")

    m = re.search(r'\\begin\{document\}(.*)\\end\{document\}', main_tex, re.S)
    if not m:
        error(f"No \\begin{{document}}…\\end{{document}} in {paper_dir / 'main.tex'}")

    body     = m.group(1)
    preamble = main_tex[:m.start()]

    def grab(cmd: str) -> str:
        mm = re.search(r'\\' + cmd + r'\{(.*?)\}\s*$', preamble, re.S | re.M)
        if not mm:
            mm = re.search(r'\\' + cmd + r'\{(.*)\}', preamble, re.S)
        return mm.group(1).strip() if mm else ""

    title  = strip_comments(grab("title"))
    author = clean_author(strip_comments(grab("author")))

    body = resolve_inputs(body, paper_dir)
    body = strip_comments(body)

    body = re.sub(
        r'\\begin\{abstract\}(.*?)\\end\{abstract\}',
        lambda mm: '\\section*{Abstract}\n' + mm.group(1).strip() + "\n",
        body, flags=re.S,
    )
    for macro in (r'\\maketitle', r'\\tableofcontents', r'\\newpage', r'\\appendix\b'):
        body = re.sub(macro, '', body)

    preamble_block = r"""\documentclass{article}
\usepackage{amsmath}
\usepackage{amssymb}
\newtheorem{theorem}{Theorem}
\newtheorem{lemma}{Lemma}
\newtheorem{proposition}{Proposition}
\newtheorem{corollary}{Corollary}
\newtheorem{definition}{Definition}
\newtheorem{example}{Example}
\newtheorem{remark}{Remark}
\newtheorem{note}{Note}
"""
    flat = preamble_block + "\\begin{document}\n" + body + "\n\\end{document}\n"
    out_file.write_text(flat, encoding="utf-8")
    return title, author


def _clean_markdown_whitespace(text: str) -> str:
    """Join wrapped lines into paragraphs, collapse blank lines."""
    BLOCK_RE = re.compile(
        r'^(\s*[-*+]\s|\s*\d+[.)]\s|\s*>|\s*#{1,6}\s|\s*```|\s*~~~|\s*\|)'
    )
    lines = text.split("\n")
    out_paragraphs: list[str] = []
    buf: list[str] = []

    def flush():
        if not buf:
            return
        cur: list[str] = []
        merged: list[str] = []
        for ln in buf:
            cur.append(ln.rstrip())
            if ln.endswith("  ") or ln.rstrip().endswith("\\"):
                merged.append(" ".join(s.strip() for s in cur))
                cur = []
        if cur:
            merged.append(" ".join(s.strip() for s in cur))
        out_paragraphs.append("\n".join(merged))
        buf.clear()

    for line in lines:
        if line.strip() == "":
            flush()
            out_paragraphs.append("")
            continue
        if BLOCK_RE.match(line):
            flush()
            out_paragraphs.append(line.rstrip())
            continue
        buf.append(line)

    flush()
    cleaned = "\n".join(out_paragraphs)
    cleaned = re.sub(r'[ \t]{2,}', ' ', cleaned)
    cleaned = re.sub(r'\n{3,}', '\n\n', cleaned)
    return cleaned.strip() + "\n"


def _export_one_target(slug: str, target: str) -> bool:
    conf_path = CONFIGS_PAPERS / f"{slug}.conf"
    paper_dir = PAPERS_DIR / slug

    if not conf_path.exists():
        warn(f"Unknown paper '{slug}' (no {conf_path})")
        return False
    if not paper_dir.exists():
        warn(f"Paper directory not found: {paper_dir}")
        return False

    tcfg = _load_target_conf(target)

    csl_path = CSL_DIR / tcfg["CSL_FILE"]
    if not csl_path.exists():
        warn(f"[{slug}/{target}] missing CSL style: {csl_path}")
        return False

    if not LUA_FILTER.exists():
        error(f"Missing Lua filter: {LUA_FILTER}")

    out_dir = BUILD_DIR / slug / target
    out_dir.mkdir(parents=True, exist_ok=True)

    log(f"[{slug}/{target}] flattening LaTeX sources")
    flat_tex = out_dir / "flat.tex"
    title, author = _flatten_tex(paper_dir, flat_tex, ROOT)

    meta     = load_conf(conf_path)
    bib_path = paper_dir / meta.get("BIB_FILE", "references/paper.bib")

    pandoc_args = ["pandoc", "-f", "latex", "-t", "gfm", "--wrap=none"]
    if bib_path.exists():
        shutil.copy2(bib_path, out_dir / "refs.bib")
        pandoc_args += [
            "--citeproc",
            f"--bibliography={out_dir / 'refs.bib'}",
            f"--csl={csl_path}",
        ]
    pandoc_args += [f"--lua-filter={LUA_FILTER}"]

    if tcfg.get("EXTRA_LUA_FILTER"):
        extra = SCRIPT_DIR / "lib" / tcfg["EXTRA_LUA_FILTER"]
        if extra.exists():
            pandoc_args.append(f"--lua-filter={extra}")

    log(f"[{slug}/{target}] converting to Markdown (pandoc, {tcfg['TARGET_LABEL']})")

    env_extra = {
        "EXPORT_REFERENCES_HEADING":  tcfg["REFERENCES_HEADING"],
        "EXPORT_REFERENCES_NUMBERED": tcfg["REFERENCES_NUMBERED"],
    }
    env = os.environ.copy()
    env.update(env_extra)

    raw_md = out_dir / "body.raw.md"
    result = subprocess.run(
        pandoc_args + ["flat.tex", "-o", "body.raw.md"],
        cwd=out_dir, env=env,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        warn(f"[{slug}/{target}] pandoc failed:\n{result.stderr.decode()}")
        return False

    cleaned = _clean_markdown_whitespace(raw_md.read_text(encoding="utf-8"))

    body_out = out_dir / f"{slug}.md"
    parts: list[str] = []

    if tcfg["INCLUDE_H1_TITLE"] == "1" and title:
        parts.append(f"# {title}\n")
        if tcfg["INCLUDE_BYLINE"] == "1" and author:
            parts.append(f"*{author}*\n")

    parts.append(cleaned)
    final_md = "\n".join(parts)

    fm_tpl = tcfg.get("FRONT_MATTER_TEMPLATE", "")
    if fm_tpl:
        fm = fm_tpl.replace("{{TITLE}}", title)
        fm = fm.replace("{{DATE}}", datetime.now(timezone.utc).strftime("%Y-%m-%d"))
        fm = fm.replace("{{TAGS}}", "[]")
        fm = fm.replace("{{AUTHOR}}", author)
        if tcfg["FRONT_MATTER_COMMENTED"] == "1":
            fm = (
                "<!--\nFront matter (uncomment if publishing via API/CLI):\n\n"
                + fm + "-->\n\n"
            )
        final_md = fm + final_md

    body_out.write_text(final_md, encoding="utf-8")
    success(f"[{slug}/{target}] Markdown → build/{slug}/{target}/{slug}.md")
    return True


def _available_targets() -> list[str]:
    return [f.stem.replace(".target", "") for f in sorted(TARGETS_DIR.glob("*.target.sh"))]


def cmd_export(slug_input: str = "", *extra_targets: str) -> None:
    if not slug_input:
        print()
        print(f"  {BOLD}Export Paper to Markdown{RESET}")
        print()
        cmd_list()
        slug_input = prompt("Slug to export (or 'all')")
        if not slug_input:
            error("Slug cannot be empty.")

        print()
        avail = _available_targets()
        print("  Platform target(s) — comma-separated, or blank for all:")
        print(f"    {', '.join(avail)}")
        raw = prompt("Target(s)", default="")
        extra_targets = tuple(t.strip() for t in raw.split(",") if t.strip()) if raw else ()

    targets = list(extra_targets) if extra_targets else _available_targets()

    if slug_input == "all":
        passed, failed = [], []
        for conf in list_conf_files(CONFIGS_PAPERS):
            slug = conf.stem
            ok = all(_export_one_target(slug, t) for t in targets)
            (passed if ok else failed).append(slug)
        print()
        success(f"Export summary: {len(passed)} passed, {len(failed)} failed"
                f" (targets: {', '.join(targets)})")
        for s in passed: print(f"  {GREEN}✓{RESET} {s}")
        for s in failed: print(f"  {RED}✗{RESET} {s}")
        if failed:
            sys.exit(1)
    else:
        slug = resolve_by_index(CONFIGS_PAPERS, slug_input)
        failed = [t for t in targets if not _export_one_target(slug, t)]
        if failed:
            sys.exit(1)


# ── delete ────────────────────────────────────────────────────────────────────

def cmd_delete(slug_input: str = "") -> None:
    if not slug_input:
        print()
        print(f"  {BOLD}Delete Paper{RESET}")
        print()
        cmd_list()
        slug_input = prompt("Slug to delete")
        if not slug_input:
            error("Slug cannot be empty.")

    slug      = resolve_by_index(CONFIGS_PAPERS, slug_input)
    paper_dir = PAPERS_DIR / slug
    conf_path = CONFIGS_PAPERS / f"{slug}.conf"

    if not paper_dir.exists() and not conf_path.exists():
        error(f"Nothing to delete: no papers/{slug} and no configs/papers/{slug}.conf")

    title = ""
    if conf_path.exists():
        title = load_conf(conf_path).get("PAPER_TITLE", "")

    print()
    warn("This will permanently delete:")
    if paper_dir.exists():   print(f"    papers/{slug}/")
    if conf_path.exists():   print(f"    configs/papers/{slug}.conf")
    build_slug = BUILD_DIR / slug
    if build_slug.exists():  print(f"    build/{slug}/")
    print(f"    its row in papers/LIST_OF_PAPERS.md")
    print()

    if not confirm_slug(slug):
        error("Confirmation did not match — nothing deleted.")

    if paper_dir.exists():   shutil.rmtree(paper_dir)
    if conf_path.exists():   conf_path.unlink()
    if build_slug.exists():  shutil.rmtree(build_slug)

    if title:
        safe = re.sub(r'[^A-Za-z0-9_-]', '', title.replace(" ", "_"))
        for f in BUILD_DIR.glob(f"*{safe}*.pdf"):
            f.unlink()

    log(f"Removed papers/{slug}, its config, and build artifacts")
    _update_papers_list()
    success(f"Deleted: {slug}")
    print()
    print("  Remaining papers have been renumbered — run 'python scripts/papers.py list'.")
    print()


# ── update papers list ────────────────────────────────────────────────────────

def _update_papers_list() -> None:
    list_file = PAPERS_DIR / "LIST_OF_PAPERS.md"
    readme    = ROOT / "README.md"

    rows_md: list[str] = [
        "# Papers — List of Papers\n",
        "\n| # | Slug | Style | Title |\n",
        "|---|------|-------|-------|\n",
    ]
    readme_rows: list[str] = []

    for idx, conf in enumerate(list_conf_files(CONFIGS_PAPERS), 1):
        slug  = conf.stem
        meta  = load_conf(conf)
        style = meta.get("PAPER_STYLE", "—")
        title = meta.get("PAPER_TITLE", "")
        year  = meta.get("PAPER_YEAR",  datetime.now(timezone.utc).strftime("%Y"))

        safe     = re.sub(r'[^A-Za-z0-9_-]', '', title.replace(" ", "_"))
        pdf_name = f"{year}_Genix_{safe}.pdf"

        rows_md.append(f"| {idx:02d} | `{slug}` | {style} | {title} |\n")
        readme_rows.append(
            f"| {idx:02d} | `{slug}` | {style} "
            f"| [{title}]({RELEASE_BASE_URL}/{pdf_name}) |\n"
        )

    list_file.write_text("".join(rows_md), encoding="utf-8")

    if not readme.exists():
        return

    BEGIN = "<!-- papers-index:begin -->"
    END   = "<!-- papers-index:end -->"
    block = (
        BEGIN + "\n## Papers Index\n\n"
        "| # | Slug | Style | Title |\n"
        "|---|------|-------|-------|\n"
        + "".join(readme_rows)
        + END
    )

    content = readme.read_text(encoding="utf-8")
    if BEGIN in content and END in content:
        start   = content.index(BEGIN)
        end     = content.index(END) + len(END)
        content = content[:start] + block + content[end:]
    else:
        content = content.rstrip() + "\n\n" + block + "\n"

    readme.write_text(content, encoding="utf-8")


# ── module class ──────────────────────────────────────────────────────────────

class PapersModule(BaseModule):
    @property
    def name(self) -> str:
        return "Papers"

    @property
    def script_name(self) -> str:
        return "papers.py"

    @property
    def commands(self) -> dict:
        return {
            "new":    (cmd_new,    "<slug> [style]       Scaffold a new paper"),
            "build":  (cmd_build,  "<slug|#|all>         Build paper(s) to PDF"),
            "export": (cmd_export, "<slug|#|all> [tgt…]  Export to Markdown"),
            "watch":  (cmd_watch,  "<slug|#>             Auto-rebuild on change"),
            "list":   (cmd_list,   "                      List all papers"),
            "styles": (cmd_styles, "                      Show available styles"),
            "clean":  (cmd_clean,  "[slug|#]             Remove build artifacts"),
            "delete": (cmd_delete, "<slug|#>             Delete a paper"),
        }

    @property
    def menu_items(self) -> list[tuple]:
        return [
            ("1", "new",    "new      — Scaffold a new paper"),
            ("2", "build",  "build    — Build a paper to PDF"),
            ("3", "all",    "build all — Build all papers"),
            ("4", "export", "export   — Export a paper to Markdown"),
            ("5", "watch",  "watch    — Watch mode (auto-rebuild)"),
            ("6", "list",   "list     — List all papers"),
            ("7", "styles", "styles   — Show available styles"),
            ("8", "clean",  "clean    — Remove build artifacts"),
            ("9", "delete", "delete   — Delete a paper completely"),
        ]


# ── entry point ───────────────────────────────────────────────────────────────

def main() -> None:
    PapersModule().main()


if __name__ == "__main__":
    main()