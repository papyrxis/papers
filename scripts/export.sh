#!/usr/bin/env bash
# Usage:
#   bash scripts/export.sh <slug|#|all> [target ...]
#   bash scripts/export.sh <slug|#|all> all-targets
#
#   slug|#       — paper to export (full slug, or its `make list` position)
#   all          — every paper with a configs/papers/*.conf
#   target ...   — one or more of: devto, medium, reddit, ieee, ssrn,
#                   scirp, journal, personal (see scripts/lib/targets/).
#                   Omit entirely (or pass "all-targets") to export every
#                   target at once.
#
# Output lands at build/<slug>/<target>/<slug>.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$ROOT/build"
LUA_FILTER="$SCRIPT_DIR/lib/clean-export.lua"
CSL_DIR="$SCRIPT_DIR/lib/csl"
TARGETS_DIR="$SCRIPT_DIR/lib/targets"
source "$SCRIPT_DIR/lib/resolve-paper.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; RESET='\033[0m'

log()     { echo -e "${BLUE}[export]${RESET} $*"; }
success() { echo -e "${GREEN}[export]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[export]${RESET} $*"; }
die()     { echo -e "${RED}[export]${RESET} $*" >&2; exit 1; }

usage() {
  echo "Usage: $(basename "$0") <slug|#|all> [target ...]" >&2
  echo "Available targets:" >&2
  for f in "$TARGETS_DIR"/*.target.sh; do
    [[ -f "$f" ]] || continue
    echo "  - $(basename "$f" .target.sh)" >&2
  done
  exit 1
}

[[ $# -ge 1 ]] || usage
SLUG="$1"; shift || true
if [[ "$SLUG" != "all" ]]; then
  SLUG="$(resolve_paper "$ROOT" "$SLUG")" || exit 1
fi

TARGETS=()
if [[ $# -eq 0 || "${1:-}" == "all-targets" ]]; then
  for f in "$TARGETS_DIR"/*.target.sh; do
    [[ -f "$f" ]] || continue
    TARGETS+=("$(basename "$f" .target.sh)")
  done
else
  TARGETS=("$@")
fi

command -v pandoc >/dev/null 2>&1 || die "pandoc not found on PATH — install it to export Markdown"
[[ -f "$LUA_FILTER" ]] || die "missing filter: ${LUA_FILTER#$ROOT/}"

for t in "${TARGETS[@]}"; do
  [[ -f "$TARGETS_DIR/${t}.target.sh" ]] || die "unknown target '$t' (no scripts/lib/targets/${t}.target.sh)"
done

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

clean_markdown_whitespace() {
  local in_file="$1"
  local out_file="$2"

  python3 - "$in_file" "$out_file" <<'PYEOF'
import re
import sys

in_path, out_path = sys.argv[1], sys.argv[2]
text = open(in_path, encoding="utf-8").read()

lines = text.split("\n")
out_paragraphs = []
buf = []

BLOCK_PREFIX = re.compile(
    r'^(\s*[-*+]\s|\s*\d+[.)]\s|\s*>|\s*#{1,6}\s|\s*```|\s*~~~|\s*\|)'
)

def flush():
    if not buf:
        return
    if len(buf) == 1:
        joined = buf[0]
    else:
        # A line ending with two trailing spaces or a backslash is an
        # intentional Markdown hard line-break — preserve it instead of
        # joining it onto the next line.
        joined_parts = []
        for ln in buf:
            joined_parts.append(ln)
        merged = []
        cur = []
        for ln in joined_parts:
            cur.append(ln.rstrip())
            if ln.endswith("  ") or ln.rstrip().endswith("\\"):
                merged.append(" ".join(s.strip() for s in cur))
                cur = []
        if cur:
            merged.append(" ".join(s.strip() for s in cur))
        joined = "\n".join(merged)
    out_paragraphs.append(joined)
    buf.clear()

for line in lines:
    if line.strip() == "":
        flush()
        out_paragraphs.append("")
        continue
    if BLOCK_PREFIX.match(line):
        flush()
        out_paragraphs.append(line.rstrip())
        continue
    buf.append(line)

flush()

cleaned = "\n".join(out_paragraphs)

# Squeeze runs of 2+ spaces/tabs (but not newlines) down to one space,
# anywhere they survived the join (e.g. inside a single original line).
cleaned = re.sub(r'[ \t]{2,}', ' ', cleaned)

# Collapse 3+ consecutive blank lines down to a single blank line.
cleaned = re.sub(r'\n{3,}', '\n\n', cleaned)

open(out_path, "w", encoding="utf-8").write(cleaned.strip() + "\n")
PYEOF
}

tex_to_markdown() {
  local flat_tex="$1"
  local bib_file="$2"
  local md_out="$3"
  local csl_path="$4"
  local references_heading="$5"
  local references_numbered="$6"
  local extra_lua_filter="${7:-}"   # optional; set by target via EXTRA_LUA_FILTER
  local work_dir="$(dirname "$flat_tex")"

  local pandoc_args=(-f latex -t gfm --wrap=none)

  if [[ -n "$bib_file" && -f "$bib_file" ]]; then
    cp "$bib_file" "$work_dir/refs.bib"
    pandoc_args+=(--citeproc --bibliography="refs.bib" --csl="$csl_path")
  fi

  pandoc_args+=(--lua-filter="$LUA_FILTER")

  if [[ -n "$extra_lua_filter" && -f "$extra_lua_filter" ]]; then
    pandoc_args+=(--lua-filter="$extra_lua_filter")
  fi

  (
    cd "$work_dir"
    EXPORT_REFERENCES_HEADING="$references_heading" \
    EXPORT_REFERENCES_NUMBERED="$references_numbered" \
    pandoc "${pandoc_args[@]}" "$(basename "$flat_tex")" -o body.raw.md
  )

  clean_markdown_whitespace "$work_dir/body.raw.md" "$work_dir/body.md"

  local title author
  title="$(sed -n '1p' "$work_dir/meta.txt")"
  author="$(sed -n '2p' "$work_dir/meta.txt" | tr -s ' \t\n' ' ')"
  author="${author% }"

  {
    if [[ "$INCLUDE_H1_TITLE" == "1" && -n "$title" ]]; then
      echo "# $title"
      echo ""
      if [[ "$INCLUDE_BYLINE" == "1" && -n "$author" ]]; then
        echo "*$author*"
        echo ""
      fi
    fi
    cat "$work_dir/body.md"
  } > "$md_out"
}

write_front_matter_file() {
  local template="$1"
  local commented="$2"
  local title="$3"
  local out_file="$4"

  [[ -n "$template" ]] || return 0

  local rendered="${template//\{\{TITLE\}\}/$title}"
  rendered="${rendered//\{\{DATE\}\}/$(date +%Y-%m-%d)}"
  rendered="${rendered//\{\{TAGS\}\}/[]}"
  rendered="${rendered//\{\{AUTHOR\}\}/$title}"

  if [[ "$commented" == "1" ]]; then
    {
      echo "<!--"
      echo "Front matter (uncomment if publishing via API/CLI instead of pasting"
      echo "into the web editor):"
      echo ""
      echo "$rendered"
      echo "-->"
      echo ""
    } > "$out_file"
  else
    {
      echo "$rendered"
    } > "$out_file"
  fi
}

export_one_target() {
  local slug="$1"
  local target="$2"
  local conf="$ROOT/configs/papers/${slug}.conf"
  local paper_dir="$ROOT/papers/${slug}"

  [[ -f "$conf" ]] || die "unknown paper '$slug' (no $conf)"
  [[ -d "$paper_dir" ]] || die "paper directory not found: $paper_dir"

  TARGET_LABEL=""; CSL_FILE=""; REFERENCES_HEADING="References"
  REFERENCES_NUMBERED="0"; OUTPUT_EXT="md"
  FRONT_MATTER_TEMPLATE=""; FRONT_MATTER_COMMENTED="0"
  INCLUDE_H1_TITLE="1"; INCLUDE_BYLINE="1"
  EXTRA_LUA_FILTER="" 
  source "$TARGETS_DIR/${target}.target.sh"

  local csl_path="$CSL_DIR/$CSL_FILE"
  [[ -f "$csl_path" ]] || die "[$slug/$target] missing CSL style: ${csl_path#$ROOT/}"

  local out_dir="$BUILD_DIR/$slug/$target"
  mkdir -p "$out_dir"

  log "[$slug/$target] flattening LaTeX sources"
  flatten_tex "$paper_dir" "$out_dir/flat.tex" "$ROOT"

  source <(tr -d '\r' < "$conf")
  local bib_path=""
  if [[ -n "${BIB_FILE:-}" && -f "$paper_dir/$BIB_FILE" ]]; then
    bib_path="$paper_dir/$BIB_FILE"
  fi

  log "[$slug/$target] converting to Markdown (pandoc, ${TARGET_LABEL:-$target})"
  local body_out="$out_dir/${slug}.md"
  tex_to_markdown "$out_dir/flat.tex" "$bib_path" "$body_out" "$csl_path" \
    "$REFERENCES_HEADING" "$REFERENCES_NUMBERED" "${EXTRA_LUA_FILTER:-}"

  if [[ -n "$FRONT_MATTER_TEMPLATE" ]]; then
    local title
    title="$(sed -n '1p' "$out_dir/meta.txt")"
    local fm_file="$out_dir/frontmatter.snippet.md"
    write_front_matter_file "$FRONT_MATTER_TEMPLATE" "$FRONT_MATTER_COMMENTED" "$title" "$fm_file"
    cat "$fm_file" "$body_out" > "${body_out}.tmp" && mv "${body_out}.tmp" "$body_out"
  fi

  success "[$slug/$target] Markdown -> build/$slug/$target/${slug}.md"
}

export_one_paper() {
  local slug="$1"
  local any_failed=0
  for t in "${TARGETS[@]}"; do
    if ! export_one_target "$slug" "$t"; then
      any_failed=1
    fi
  done
  return $any_failed
}

case "$SLUG" in
  all)
    PASSED=(); FAILED=()
    for conf in "$ROOT"/configs/papers/*.conf; do
      [[ -f "$conf" ]] || continue
      s="$(basename "$conf" .conf)"
      if export_one_paper "$s"; then PASSED+=("$s"); else FAILED+=("$s"); fi
    done
    echo ""
    success "Export summary: ${#PASSED[@]} passed, ${#FAILED[@]} failed (targets: ${TARGETS[*]})"
    for s in "${PASSED[@]}"; do echo -e "  ${GREEN}✓${RESET} $s"; done
    for s in "${FAILED[@]}"; do echo -e "  ${RED}✗${RESET} $s"; done
    [[ ${#FAILED[@]} -eq 0 ]] || exit 1
    ;;
  *)
    export_one_paper "$SLUG"
    ;;
esac