#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$ROOT/dist"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; RESET='\033[0m'

log()     { echo -e "${BLUE}[export]${RESET} $*"; }
success() { echo -e "${GREEN}[export]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[export]${RESET} $*"; }
die()     { echo -e "${RED}[export]${RESET} $*" >&2; exit 1; }

usage() { echo "Usage: $(basename "$0") <slug|all>" >&2; exit 1; }

[[ $# -ge 1 ]] || usage
SLUG="$1"

build_pdf() {
  local slug="$1"
  log "[$slug] building PDF via scripts/build.sh"
  bash "$SCRIPT_DIR/build.sh" "$slug"
}

flatten_tex() {
  local paper_dir="$1"
  local out_file="$2"

  python3 - "$paper_dir" "$out_file" <<'PYEOF'
import re
import sys
from pathlib import Path

paper_dir = Path(sys.argv[1])
out_file = Path(sys.argv[2])

def resolve_inputs(text, base_dir, depth=0):
    if depth > 12:
        return text

    def repl(m):
        rel = m.group(1).strip()
        # try as given, then with .tex appended
        candidates = [base_dir / rel, base_dir / f"{rel}.tex"]
        for c in candidates:
            if c.is_file():
                inner = c.read_text(encoding="utf-8", errors="replace")
                return resolve_inputs(inner, c.parent, depth + 1)
        # couldn't resolve (likely a preamble/style file we don't want) -> drop it
        return ""

    return re.sub(r'\\input\{([^}]+)\}', repl, text)

main_tex = (paper_dir / "main.tex").read_text(encoding="utf-8", errors="replace")

# Extract the body between \begin{document} and \end{document}
m = re.search(r'\\begin\{document\}(.*)\\end\{document\}', main_tex, re.S)
body = m.group(1) if m else main_tex

# Capture title/author/date from the preamble (before \begin{document}) for a Markdown header
preamble = main_tex[:m.start()] if m else ""

def grab(cmd):
    mm = re.search(r'\\' + cmd + r'\{(.*?)\}\s*$', preamble, re.S | re.M)
    if not mm:
        mm = re.search(r'\\' + cmd + r'\{(.*)\}', preamble, re.S)
    return mm.group(1).strip() if mm else ""

def strip_comments(s):
    # Remove unescaped "%...\n" line comments, then collapse the
    # resulting line-continuation gaps.
    out_lines = []
    for line in s.split("\n"):
        # find an unescaped %
        idx = None
        i = 0
        while i < len(line):
            if line[i] == '%' and (i == 0 or line[i-1] != '\\'):
                idx = i
                break
            i += 1
        out_lines.append(line[:idx] if idx is not None else line)
    return "\n".join(out_lines)

title = strip_comments(grab("title"))
author = strip_comments(grab("author"))

body = resolve_inputs(body, paper_dir)
body = strip_comments(body)

# Drop \maketitle / \tableofcontents / \newpage — meaningless in Markdown
body = re.sub(r'\\maketitle', '', body)
body = re.sub(r'\\tableofcontents', '', body)
body = re.sub(r'\\newpage', '', body)

# Standalone preamble: standard documentclass + packages/theorem
# environments that the project's custom style files (which we don't
# feed to pandoc) would otherwise have provided.
preamble_block = """\\documentclass{article}
\\usepackage{amsmath}
\\usepackage{amssymb}
\\newtheorem{theorem}{Theorem}
\\newtheorem{lemma}{Lemma}
\\newtheorem{proposition}{Proposition}
\\newtheorem{corollary}{Corollary}
\\newtheorem{definition}{Definition}
\\newtheorem{example}{Example}
\\newtheorem{remark}{Remark}
\\newtheorem{note}{Note}
"""

flat = preamble_block
if title:
    flat += f"\\title{{{title}}}\n"
if author:
    flat += f"\\author{{{author}}}\n"
flat += "\\begin{document}\n"
if title:
    flat += "\\maketitle\n"
flat += body
flat += "\n\\end{document}\n"

out_file.write_text(flat, encoding="utf-8")
PYEOF
}
tex_to_markdown() {
  local flat_tex="$1"
  local bib_file="$2"
  local md_out="$3"

  local pandoc_args=(
    -f latex
    -t gfm
    --wrap=preserve
    --standalone
  )

  if [[ -n "$bib_file" && -f "$bib_file" ]]; then
    local bib_copy="$(dirname "$flat_tex")/refs.bib"
    cp "$bib_file" "$bib_copy"
    pandoc_args+=(--citeproc --bibliography="refs.bib")
  fi

  (cd "$(dirname "$flat_tex")" && pandoc "${pandoc_args[@]}" "$(basename "$flat_tex")" -o "$md_out")
}

export_one() {
  local slug="$1"
  local conf="$ROOT/configs/papers/${slug}.conf"
  local paper_dir="$ROOT/papers/${slug}"

  [[ -f "$conf" ]] || die "unknown paper '$slug' (no $conf)"
  [[ -d "$paper_dir" ]] || die "paper directory not found: $paper_dir"

  mkdir -p "$DIST_DIR/$slug"

  # 1) PDF
  build_pdf "$slug"
  local pdf_src
  pdf_src="$(find "$ROOT/build/$slug" -maxdepth 1 -name 'main.pdf' | head -n1)"
  [[ -f "$pdf_src" ]] || die "[$slug] PDF build did not produce main.pdf"
  cp "$pdf_src" "$DIST_DIR/$slug/${slug}.pdf"
  success "[$slug] PDF -> dist/$slug/${slug}.pdf"

  # 2) Markdown
  log "[$slug] flattening LaTeX sources"
  local flat_tex="$ROOT/build/$slug/flat.tex"
  mkdir -p "$ROOT/build/$slug"
  flatten_tex "$paper_dir" "$flat_tex"

  source <(tr -d '\r' < "$conf")
  local bib_path=""
  if [[ -n "${BIB_FILE:-}" && -f "$paper_dir/$BIB_FILE" ]]; then
    bib_path="$paper_dir/$BIB_FILE"
  fi

  log "[$slug] converting to Markdown (pandoc)"
  tex_to_markdown "$flat_tex" "$bib_path" "$DIST_DIR/$slug/${slug}.md"
  success "[$slug] Markdown -> dist/$slug/${slug}.md"
}

case "$SLUG" in
  all)
    PASSED=(); FAILED=()
    for conf in "$ROOT"/configs/papers/*.conf; do
      [[ -f "$conf" ]] || continue
      s="$(basename "$conf" .conf)"
      if export_one "$s"; then PASSED+=("$s"); else FAILED+=("$s"); fi
    done
    echo ""
    success "Export summary: ${#PASSED[@]} passed, ${#FAILED[@]} failed"
    for s in "${PASSED[@]}"; do echo -e "  ${GREEN}✓${RESET} $s"; done
    for s in "${FAILED[@]}"; do echo -e "  ${RED}✗${RESET} $s"; done
    [[ ${#FAILED[@]} -eq 0 ]] || exit 1
    ;;
  *)
    export_one "$SLUG"
    ;;
esac
