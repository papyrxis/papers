#!/usr/bin/env bash
# export-chapters.sh — Export booklet chapter(s) to Markdown/HTML for article platforms
#
# Usage:
#   bash scripts/lib/export-chapters.sh <slug> <lang> [chapters] [targets]
#
# Arguments:
#   slug      Booklet slug, e.g. 01-what-data-is-and-why-it-must-become-physical
#   lang      Language: en | fa   (default: en)
#   chapters  Comma-separated chapter numbers, or "all"  (default: all)
#   targets   Space-separated platform names, or "all"   (default: all)
#
# Supported targets: devto  medium  reddit  ieee  ssrn  scirp  journal  personal
#
# Examples:
#   bash scripts/lib/export-chapters.sh \
#     01-what-data-is-and-why-it-must-become-physical en "1,2" "devto ieee"
#   bash scripts/lib/export-chapters.sh \
#     01-what-data-is-and-why-it-must-become-physical en all devto
#
# Output:
#   build/booklets/<slug>/<lang>/articles/<target>/chapter0N.<ext>

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

log()     { echo -e "  ${DIM}··${RESET} $*"; }
success() { echo -e "  ${GREEN}✓${RESET}  $*"; }
warn()    { echo -e "  ${YELLOW}⚠${RESET}  $*"; }
error()   { echo -e "  ${RED}✗${RESET}  $*" >&2; exit 1; }
hr()      { echo -e "  ${DIM}──────────────────────────────────────────────────────${RESET}"; }

# ── Paths ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGETS_DIR="$SCRIPT_DIR/targets"
CSL_DIR="$SCRIPT_DIR/csl"
LUA_FILTER="$SCRIPT_DIR/clean-export.lua"

# ── Arguments ─────────────────────────────────────────────────────────────────
SLUG="${1:-}"
LANG="${2:-en}"
CHAPTERS="${3:-all}"
TARGETS_INPUT="${4:-all}"

[[ -z "$SLUG" ]] && error "Usage: export-chapters.sh <slug> [lang] [chapters] [targets]"

BOOKLET_DIR="$ROOT/booklets/$SLUG/$LANG"
CHAPTERS_DIR="$BOOKLET_DIR/chapters"
BIB_FILE="$ROOT/booklets/$SLUG/references/paper.bib"
SHARED_BIB="$ROOT/booklets/shared/$LANG/backmatter/default.bib"

[[ -d "$BOOKLET_DIR"  ]] || error "Booklet not found: booklets/$SLUG/$LANG/"
[[ -d "$CHAPTERS_DIR" ]] || error "Chapters directory missing: booklets/$SLUG/$LANG/chapters/"

command -v pandoc &>/dev/null \
  || error "pandoc not found — install it: https://pandoc.org/installing.html"

command -v python3 &>/dev/null \
  || error "python3 not found — needed to build the cross-reference label map."

# ── Resolve chapter files ─────────────────────────────────────────────────────
declare -a CHAPTER_FILES
if [[ "$CHAPTERS" == "all" ]]; then
  while IFS= read -r f; do CHAPTER_FILES+=("$f"); done \
    < <(find "$CHAPTERS_DIR" -name "chapter*.tex" | sort)
else
  IFS=',' read -ra NUMS <<< "$CHAPTERS"
  for n in "${NUMS[@]}"; do
    n="${n// /}"
    f="$CHAPTERS_DIR/chapter$(printf '%02d' "$n").tex"
    [[ -f "$f" ]] || error "Chapter file not found: $f"
    CHAPTER_FILES+=("$f")
  done
fi

[[ ${#CHAPTER_FILES[@]} -gt 0 ]] || error "No chapter files found in $CHAPTERS_DIR"

# ── Resolve export targets ────────────────────────────────────────────────────
declare -a TARGET_LIST
if [[ "$TARGETS_INPUT" == "all" ]]; then
  while IFS= read -r f; do
    TARGET_LIST+=("$(basename "${f%.target.sh}")")
  done < <(find "$TARGETS_DIR" -name "*.target.sh" | sort)
else
  IFS=' ' read -ra TARGET_LIST <<< "$TARGETS_INPUT"
fi

[[ ${#TARGET_LIST[@]} -gt 0 ]] || error "No export targets found."

# ── Build the cross-reference label → title map ───────────────────────────────
# \ref{sec:foo} etc. only carry meaning if we know what "sec:foo" actually is.
# Scan every chapter file in this booklet/language (not just the ones being
# exported) so a reference from chapter 2 into chapter 1 still resolves to a
# real, human-readable title instead of leaking the raw LaTeX label.
LABEL_MAP="$(python3 - "$CHAPTERS_DIR" <<'PYEOF'
import re, sys, glob, os

chapters_dir = sys.argv[1]
US = "\x1f"  # unit separator: key<US>title
RS = "\x1e"  # record separator: between entries

pattern = re.compile(
    r'\\(?:chapter|section|subsection|subsubsection)\{([^}]*)\}\s*\r?\n\s*\\label\{([^}]*)\}'
)

out = []
for path in sorted(glob.glob(os.path.join(chapters_dir, "chapter*.tex"))):
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    for m in pattern.finditer(text):
        title, label = m.group(1), m.group(2)
        # Strip nested LaTeX commands from the title in a best-effort way.
        title = re.sub(r'\\[a-zA-Z]+\{([^}]*)\}', r'\1', title)
        out.append(label + US + title)

sys.stdout.write(RS.join(out))
PYEOF
)"

# ── Header ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  Booklet Chapter Export${RESET}"
hr
echo -e "  Booklet  : ${CYAN}$SLUG${RESET} (${LANG})"
echo -e "  Chapters : ${CYAN}${#CHAPTER_FILES[@]}${RESET} file(s): $(
  for f in "${CHAPTER_FILES[@]}"; do printf "%s " "$(basename "$f" .tex)"; done)"
echo -e "  Targets  : ${CYAN}${TARGET_LIST[*]}${RESET}"
echo ""

FAIL=0

# ── Export loop ───────────────────────────────────────────────────────────────
for TARGET in "${TARGET_LIST[@]}"; do
  TFILE="$TARGETS_DIR/$TARGET.target.sh"
  if [[ ! -f "$TFILE" ]]; then
    warn "Unknown target '$TARGET' (no $TFILE) — skipping."
    continue
  fi

  # ── Load target config defaults then override ─────────────────────────────
  TARGET_LABEL="$TARGET"
  CSL_FILE="ieee.csl"
  REFERENCES_HEADING="References"
  REFERENCES_NUMBERED="1"
  OUTPUT_EXT="md"
  FRONT_MATTER_TEMPLATE=""
  FRONT_MATTER_COMMENTED="0"
  INCLUDE_H1_TITLE="1"
  INCLUDE_BYLINE="0"
  BYLINE_TEXT="By Mahdi Mamashli (Genix)"
  DISABLE_FENCED_CODE="0"
  EXTRA_LUA_FILTER=""
  # shellcheck source=/dev/null
  source "$TFILE"

  CSL_PATH="$CSL_DIR/$CSL_FILE"
  if [[ ! -f "$CSL_PATH" ]]; then
    warn "CSL style not found: $CSL_PATH — skipping target $TARGET."
    continue
  fi

  # ── Writer selection ───────────────────────────────────────────────────────
  # HTML targets (e.g. medium) get a real HTML writer: platforms that don't
  # parse Markdown on paste need actual <h1>/<strong>/<em> markup, not
  # literal '#'/'**' characters.
  if [[ "$OUTPUT_EXT" == "html" ]]; then
    PANDOC_TO="html"
  else
    # "-citations" is the load-bearing fix here: with it left enabled (the
    # pandoc default) the markdown writer re-serializes every citeproc-resolved
    # citation back into raw "[@key]" pandoc syntax instead of the rendered
    # "[1]" / "(Author, Year)" text, which is why references never actually
    # rendered in ANY of the markdown targets before this fix.
    PANDOC_TO="markdown-citations"
    if [[ "$DISABLE_FENCED_CODE" == "1" ]]; then
      # Old Reddit doesn't render ``` fences at all — only 4-space-indented
      # code blocks. Disabling this extension makes the writer fall back to
      # indented blocks automatically.
      PANDOC_TO="${PANDOC_TO}-fenced_code_blocks"
    fi
  fi

  # ── Env vars consumed by clean-export.lua ──────────────────────────────────
  # (Previously these bash variables were set but never exported, so the Lua
  # filter always fell back to its own defaults — every target silently got
  # "References" + unnumbered, regardless of what was configured here.)
  export EXPORT_REFERENCES_HEADING="$REFERENCES_HEADING"
  export EXPORT_REFERENCES_NUMBERED="$REFERENCES_NUMBERED"
  export EXPORT_LABEL_MAP="$LABEL_MAP"
  export EXPORT_HTML_OUTPUT="$([[ "$OUTPUT_EXT" == "html" ]] && echo 1 || echo 0)"

  echo -e "  ${BOLD}▸ ${TARGET_LABEL}${RESET}"

  for CHAP_FILE in "${CHAPTER_FILES[@]}"; do
    CHAP_BASENAME="$(basename "$CHAP_FILE" .tex)"
    OUT_DIR="$ROOT/build/booklets/$SLUG/$LANG/articles/$TARGET"
    OUT_FILE="$OUT_DIR/$CHAP_BASENAME.$OUTPUT_EXT"
    mkdir -p "$OUT_DIR"

    log "[${TARGET_LABEL}] ${CHAP_BASENAME}"

    # Warn if chapter is marked as in-progress
    if grep -q 'still being written\|not yet in a state' "$CHAP_FILE" 2>/dev/null; then
      warn "Chapter ${CHAP_BASENAME} is marked as in-progress — exporting anyway."
    fi

    # ── Preprocess ────────────────────────────────────────────────────────────
    # Convert biblatex cite commands → \cite so pandoc processes them correctly
    TMP_TEX="$(mktemp --suffix=.tex)"
    sed 's/\\autocite\b/\\cite/g;
         s/\\textcite\b/\\cite/g;
         s/\\parencite\b/\\cite/g;
         s/\\footcite\b/\\cite/g;
         s/\\citeauthor\b/\\cite/g' "$CHAP_FILE" > "$TMP_TEX"

    # ── Build pandoc arguments ────────────────────────────────────────────────
    PANDOC_ARGS=(
      "$TMP_TEX"
      --from "latex+raw_tex"
      --to   "$PANDOC_TO"
      --wrap=none
    )

    # Bibliography sources
    [[ -f "$BIB_FILE"   ]] && PANDOC_ARGS+=(--bibliography "$BIB_FILE")
    [[ -f "$SHARED_BIB" ]] && PANDOC_ARGS+=(--bibliography "$SHARED_BIB")

    # Citation processing
    PANDOC_ARGS+=(--csl "$CSL_PATH" --citeproc)

    # Lua filters
    [[ -f "$LUA_FILTER" ]] && PANDOC_ARGS+=(--lua-filter "$LUA_FILTER")
    if [[ -n "$EXTRA_LUA_FILTER" && -f "$EXTRA_LUA_FILTER" ]]; then
      PANDOC_ARGS+=(--lua-filter "$EXTRA_LUA_FILTER")
    fi

    PANDOC_ARGS+=(-o "$OUT_FILE")

    # ── Run pandoc ────────────────────────────────────────────────────────────
    PANDOC_ERR="$(mktemp)"
    if pandoc "${PANDOC_ARGS[@]}" 2>"$PANDOC_ERR"; then
      rm -f "$TMP_TEX" "$PANDOC_ERR"

      # ── Post-process (markdown targets only) ────────────────────────────────
      if [[ "$OUTPUT_EXT" != "html" ]]; then
        # pandoc's markdown writer escapes every literal "[" / "]" as "\[" / "\]"
        # to protect against being misread as link syntax. A CommonMark renderer
        # (dev.to, GitHub, new-Reddit) unescapes this invisibly, but anyone
        # reading the raw file — or pasting into a non-Markdown destination like
        # Word/Overleaf for the academic targets — sees literal backslashes in
        # front of every citation number and reference marker. There's no
        # meaningful link syntax in this content, so it's safe to just undo it.
        sed -i 's/\\\[/[/g; s/\\\]/]/g' "$OUT_FILE"

        if [[ "$INCLUDE_H1_TITLE" != "1" ]]; then
          # Drop a leading "# Title" line — used for platforms (Reddit) where
          # the submission's own title field already carries it, so repeating
          # it as a giant heading in the body is redundant.
          sed -i '0,/^# /{/^# /d}' "$OUT_FILE"
          sed -i '/./,$!d' "$OUT_FILE"  # trim any now-leading blank lines
        fi
      fi

      if [[ "$INCLUDE_BYLINE" == "1" ]]; then
        TMP_BYLINE="$(mktemp)"
        if [[ "$OUTPUT_EXT" == "html" ]]; then
          { printf "<p><em>%s</em></p>\n" "$BYLINE_TEXT"; cat "$OUT_FILE"; } > "$TMP_BYLINE"
        else
          { printf "*%s*\n\n" "$BYLINE_TEXT"; cat "$OUT_FILE"; } > "$TMP_BYLINE"
        fi
        mv "$TMP_BYLINE" "$OUT_FILE"
      fi

      # ── Prepend front matter ───────────────────────────────────────────────
      if [[ -n "$FRONT_MATTER_TEMPLATE" ]]; then
        CHAP_TITLE="$(grep -m1 '\\chapter{' "$CHAP_FILE" \
          | sed 's/.*\\chapter{//; s/}.*//')"
        FM="$FRONT_MATTER_TEMPLATE"
        FM="${FM//\{\{TITLE\}\}/$CHAP_TITLE}"
        FM="${FM//\{\{DATE\}\}/$(date +%Y-%m-%d)}"
        FM="${FM//\{\{AUTHOR\}\}/Mahdi Mamashli (Genix)}"
        FM="${FM//\{\{TAGS\}\}/data, computer-science, information-theory, philosophy}"
        TMP_FM="$(mktemp)"
        if [[ "$FRONT_MATTER_COMMENTED" == "1" ]]; then
          { printf "<!--\n%s-->\n\n" "$FM"; cat "$OUT_FILE"; } > "$TMP_FM"
        else
          { printf "%s\n" "$FM"; cat "$OUT_FILE"; } > "$TMP_FM"
        fi
        mv "$TMP_FM" "$OUT_FILE"
      fi

      success "build/booklets/$SLUG/$LANG/articles/$TARGET/${CHAP_BASENAME}.${OUTPUT_EXT}"
    else
      PANDOC_MSG="$(cat "$PANDOC_ERR")"
      rm -f "$TMP_TEX" "$PANDOC_ERR"
      warn "pandoc failed for [${TARGET}] ${CHAP_BASENAME}: ${PANDOC_MSG}"
      FAIL=1
    fi
  done

  echo ""
done

# ── Summary ───────────────────────────────────────────────────────────────────
hr
if [[ $FAIL -eq 0 ]]; then
  echo -e "  ${GREEN}${BOLD}All exports complete.${RESET}"
  echo -e "  ${DIM}Output: build/booklets/$SLUG/$LANG/articles/${RESET}"
else
  echo -e "  ${YELLOW}${BOLD}Some exports failed — see warnings above.${RESET}"
fi
echo ""
exit $FAIL