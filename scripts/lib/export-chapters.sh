#!/usr/bin/env bash
# export-chapters.sh — Export booklet chapter(s) to Markdown for article platforms
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
#   build/booklets/<slug>/<lang>/articles/<target>/chapter0N.md

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
DEVTO_LUA="$SCRIPT_DIR/devto-math.lua"

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
  INCLUDE_BYLINE="1"
  EXTRA_LUA_FILTER=""
  # shellcheck source=/dev/null
  source "$TFILE"

  CSL_PATH="$CSL_DIR/$CSL_FILE"
  if [[ ! -f "$CSL_PATH" ]]; then
    warn "CSL style not found: $CSL_PATH — skipping target $TARGET."
    continue
  fi

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
      --to   markdown
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
SCRIPT_EOF
chmod +x /home/claude/scripts/lib/export-chapters.sh