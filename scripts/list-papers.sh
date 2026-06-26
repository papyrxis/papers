#!/usr/bin/env bash
# List all papers with slug, style, title, and build status.
# Also regenerates papers/LIST_OF_PAPERS.md from current configs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$ROOT/build"

BLUE='\033[0;34m'; CYAN='\033[0;36m'; GREEN='\033[0;32m'
RED='\033[0;31m'; GREY='\033[0;37m'; BOLD='\033[1m'; RESET='\033[0m'

echo ""
echo -e "${BOLD}  Papers — Genix${RESET}"
echo -e "  ──────────────────────────────────────────────────────────────────────"
printf "  %-46s %-14s %-6s  %s\n" "Slug" "Style" "Built" "Title"
echo -e "  ──────────────────────────────────────────────────────────────────────"

COUNT=0

# Regenerate LIST_OF_PAPERS.md
LIST_FILE="$ROOT/papers/LIST_OF_PAPERS.md"
{
  echo "# Papers — List of Papers"
  echo ""
  echo "| # | Slug | Style | Title |"
  echo "|---|------|-------|-------|"
} > "${LIST_FILE}.tmp"

IDX=0
for conf in "$ROOT"/configs/papers/*.conf; do
  [[ -f "$conf" ]] || continue
  IDX=$((IDX + 1))
  slug="$(basename "$conf" .conf)"

  PAPER_TITLE=""
  PAPER_STYLE=""
  source <(tr -d '\r' < "$conf") 2>/dev/null || true
  style="${PAPER_STYLE:-—}"
  title="${PAPER_TITLE:-}"

  # Check if any PDF exists in build/ matching this paper's title
  safe_title="$(echo "${PAPER_TITLE:-$slug}" | tr ' ' '_' | tr -cd 'A-Za-z0-9_-')"
  built_color="${RED}no${RESET}"
  if find "$BUILD_DIR" -maxdepth 1 -name "*${safe_title}*.pdf" 2>/dev/null | grep -q .; then
    built_color="${GREEN}yes${RESET}"
  elif find "$BUILD_DIR" -maxdepth 1 -name "*.pdf" 2>/dev/null | grep -q .; then
    built_color="${GREY}?${RESET}"
  fi

  # Truncate title for terminal display
  short_title="${title:0:52}"
  [[ ${#title} -gt 52 ]] && short_title="${short_title}…"

  printf "  %-46s %-14s " "$slug" "$style"
  echo -en "$built_color"
  printf "  %s\n" "$short_title"
  COUNT=$((COUNT + 1))

  # Append to list file
  echo "| ${IDX} | \`${slug}\` | ${style} | ${title} |" >> "${LIST_FILE}.tmp"
done

mv "${LIST_FILE}.tmp" "$LIST_FILE"

echo -e "  ──────────────────────────────────────────────────────────────────────"
echo -e "  ${COUNT} paper(s) total"
echo ""
echo -e "  ${CYAN}Build one:${RESET}    make paper PAPER=<slug>"
echo -e "  ${CYAN}Build all:${RESET}    make build"
echo -e "  ${CYAN}New paper:${RESET}    make new-paper SLUG=<slug> STYLE=<style>"
echo -e "  ${CYAN}Styles:${RESET}       personal | single-column | two-column | academic | ieee | journal"
echo ""
echo -e "  ${GREY}papers/LIST_OF_PAPERS.md updated.${RESET}"
echo ""