#!/usr/bin/env bash
# Usage: bash scripts/export.sh <slug|#|all>
#   slug   — full paper slug, e.g. 01-the-nature-of-data
#   #      — the paper's position in `make list` (1, 2, 3, ...)
#   all    — every paper with a configs/papers/*.conf

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$ROOT/build"
LUA_FILTER="$SCRIPT_DIR/lib/clean-export.lua"
source "$SCRIPT_DIR/lib/resolve-paper.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; RESET='\033[0m'

log()     { echo -e "${BLUE}[export]${RESET} $*"; }
success() { echo -e "${GREEN}[export]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[export]${RESET} $*"; }
die()     { echo -e "${RED}[export]${RESET} $*" >&2; exit 1; }

usage() { echo "Usage: $(basename "$0") <slug|#|all>" >&2; exit 1; }

[[ $# -ge 1 ]] || usage
SLUG="$1"
if [[ "$SLUG" != "all" ]]; then
  SLUG="$(resolve_paper "$ROOT" "$SLUG")" || exit 1
fi

command -v pandoc >/dev/null 2>&1 || die "pandoc not found on PATH — install it to export Markdown"
[[ -f "$LUA_FILTER" ]] || die "missing filter: ${LUA_FILTER#$ROOT/}"

flatten_tex() {
  local paper_dir="$1"
  local out_file="$2"
  local root="$3"

  python3 - "$paper_dir" "$out_file" "$root" <<'PYEOF'
import re
import sys
from pathlib import Path

paper_dir = Path(sys.argv[1])
out_file = Path(sys.argv[2])
root = Path(sys.argv[3])

def resolve_inputs(text, base_dir, depth=0):
    if depth > 12:
        return text

    def repl(m):
        rel = m.group(1).strip()
        # Try, in order: relative to the including file, relative to the
        # paper's own directory, and relative to the project root (some
        # \input paths — e.g. backmatter/bibliography — are root-relative,
        # the same way main.tex itself references them).
        candidates = [
            base_dir / rel, base_dir / f"{rel}.tex",
            paper_dir / rel, paper_dir / f"{rel}.tex",
            root / rel, root / f"{rel}.tex",
        ]
        for c in candidates:
            if c.is_file():
                inner = c.read_text(encoding="utf-8", errors="replace")
                return resolve_inputs(inner, c.parent, depth + 1)
        # Couldn't resolve — almost always a project preamble/style file
        # (.pxis/preset, configs/paper-styles) we deliberately don't feed
        # to pandoc. Drop it silently.
        return ""

    return re.sub(r'\\input\{([^}]+)\}', repl, text)

main_tex = (paper_dir / "main.tex").read_text(encoding="utf-8", errors="replace")

m = re.search(r'\\begin\{document\}(.*)\\end\{document\}', main_tex, re.S)
if not m:
    sys.exit(f"error: no \\begin{{document}}...\\end{{document}} found in {paper_dir / 'main.tex'}")
body = m.group(1)
preamble = main_tex[:m.start()]

def grab(cmd):
    mm = re.search(r'\\' + cmd + r'\{(.*?)\}\s*$', preamble, re.S | re.M)
    if not mm:
        mm = re.search(r'\\' + cmd + r'\{(.*)\}', preamble, re.S)
    return mm.group(1).strip() if mm else ""

def strip_comments(s):
    out_lines = []
    for line in s.split("\n"):
        idx = None
        i = 0
        while i < len(line):
            if line[i] == '%' and (i == 0 or line[i-1] != '\\'):
                idx = i
                break
            i += 1
        out_lines.append(line[:idx] if idx is not None else line)
    return "\n".join(out_lines)

def clean_author(s):
    # \author{} bodies commonly contain line breaks (\\) and a \small\texttt{email}
    # styling wrapper. Reduce to plain "Name <email>" text.
    s = s.replace('\\\\', '\n')
    s = re.sub(r'\\(?:small|large|Large|texttt|textit|textbf|emph)\s*', '', s)
    s = s.replace('{', '').replace('}', '')
    lines = [ln.strip() for ln in s.split('\n') if ln.strip()]
    return ' — '.join(lines).strip()

title = strip_comments(grab("title"))
author = clean_author(strip_comments(grab("author")))

body = resolve_inputs(body, paper_dir)
body = strip_comments(body)

# pandoc's LaTeX reader recognizes \begin{abstract}...\end{abstract} but
# only surfaces it as YAML front-matter metadata under --standalone — in
# plain body output (which is what we want, no YAML) the content is
# silently dropped. Turn it into a normal heading + paragraph so it
# survives into the Markdown body.
body = re.sub(
    r'\\begin\{abstract\}(.*?)\\end\{abstract\}',
    lambda m: '\\section*{Abstract}\n' + m.group(1).strip() + '\n',
    body, flags=re.S,
)

# Drop pure-LaTeX layout/numbering markers with no Markdown meaning.
body = re.sub(r'\\maketitle', '', body)
body = re.sub(r'\\tableofcontents', '', body)
body = re.sub(r'\\newpage', '', body)
body = re.sub(r'\\appendix\b', '', body)

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

flat = preamble_block + "\\begin{document}\n" + body + "\n\\end{document}\n"
out_file.write_text(flat, encoding="utf-8")

# Hand title/author back to the caller via a small sidecar file —
# simpler and more robust than smuggling them through stdout.
(out_file.parent / "meta.txt").write_text(f"{title}\n{author}\n", encoding="utf-8")
PYEOF
}

tex_to_markdown() {
  local flat_tex="$1"
  local bib_file="$2"
  local md_out="$3"
  local work_dir="$(dirname "$flat_tex")"

  local pandoc_args=(-f latex -t gfm --wrap=preserve)

  if [[ -n "$bib_file" && -f "$bib_file" ]]; then
    cp "$bib_file" "$work_dir/refs.bib"
    pandoc_args+=(--citeproc --bibliography="refs.bib")
  fi

  pandoc_args+=(--lua-filter="$LUA_FILTER")

  (cd "$work_dir" && pandoc "${pandoc_args[@]}" "$(basename "$flat_tex")" -o body.md)

  local title author
  title="$(sed -n '1p' "$work_dir/meta.txt")"
  author="$(sed -n '2p' "$work_dir/meta.txt" | tr -s ' \t\n' ' ')"
  author="${author% }"

  {
    if [[ -n "$title" ]]; then
      echo "# $title"
      echo ""
      [[ -n "$author" ]] && echo "*$author*" && echo ""
    fi
    awk 'BEGIN{blank=0} /^[[:space:]]*$/{blank++; if(blank<=1) print; next} {blank=0; print}' "$work_dir/body.md"
  } > "$md_out"
}

export_one() {
  local slug="$1"
  local conf="$ROOT/configs/papers/${slug}.conf"
  local paper_dir="$ROOT/papers/${slug}"

  [[ -f "$conf" ]] || die "unknown paper '$slug' (no $conf)"
  [[ -d "$paper_dir" ]] || die "paper directory not found: $paper_dir"

  local out_dir="$BUILD_DIR/$slug"
  mkdir -p "$out_dir"

  log "[$slug] flattening LaTeX sources"
  flatten_tex "$paper_dir" "$out_dir/flat.tex" "$ROOT"

  source <(tr -d '\r' < "$conf")
  local bib_path=""
  if [[ -n "${BIB_FILE:-}" && -f "$paper_dir/$BIB_FILE" ]]; then
    bib_path="$paper_dir/$BIB_FILE"
  fi

  log "[$slug] converting to Markdown (pandoc)"
  tex_to_markdown "$out_dir/flat.tex" "$bib_path" "$out_dir/${slug}.md"
  success "[$slug] Markdown -> build/$slug/${slug}.md"
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