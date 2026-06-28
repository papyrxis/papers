#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$ROOT/build"
README="$ROOT/README.md"

RELEASE_BASE_URL="https://github.com/papyrxis/papers/releases/download/latest-pre-release"

BLUE='\033[0;34m'; CYAN='\033[0;36m'; GREEN='\033[0;32m'
RED='\033[0;31m'; GREY='\033[0;37m'; BOLD='\033[1m'; RESET='\033[0m'

echo ""
echo -e "${BOLD}  Papers — Genix${RESET}"
echo -e "  ──────────────────────────────────────────────────────────────────────"
printf "  %-46s %-14s %-6s  %s\n" "Slug" "Style" "Built" "Title"
echo -e "  ──────────────────────────────────────────────────────────────────────"

COUNT=0

LIST_FILE="$ROOT/papers/LIST_OF_PAPERS.md"
{
  echo "# Papers — List of Papers"
  echo ""
  echo "| # | Slug | Style | Title |"
  echo "|---|------|-------|-------|"
} > "${LIST_FILE}.tmp"

README_ROWS_FILE="$(mktemp)"

IDX=0
for conf in "$ROOT"/configs/papers/*.conf; do
  [[ -f "$conf" ]] || continue
  IDX=$((IDX + 1))
  slug="$(basename "$conf" .conf)"

  PAPER_TITLE=""
  PAPER_STYLE=""
  PAPER_YEAR=""
  source <(tr -d '\r' < "$conf") 2>/dev/null || true
  style="${PAPER_STYLE:-—}"
  title="${PAPER_TITLE:-}"
  year="${PAPER_YEAR:-$(date -u '+%Y')}"

  safe_title="$(echo "${title:-$slug}" | tr ' ' '_' | tr -cd 'A-Za-z0-9_-')"
  pdf_name="${year}_Genix_${safe_title}.pdf"

  built_color="${RED}no${RESET}"
  if find "$BUILD_DIR" -maxdepth 1 -name "*${safe_title}*.pdf" 2>/dev/null | grep -q .; then
    built_color="${GREEN}yes${RESET}"
  elif find "$BUILD_DIR" -maxdepth 1 -name "*.pdf" 2>/dev/null | grep -q .; then
    built_color="${GREY}?${RESET}"
  fi

  short_title="${title:0:52}"
  [[ ${#title} -gt 52 ]] && short_title="${short_title}…"

  printf "  %-46s %-14s " "$slug" "$style"
  echo -en "$built_color"
  printf "  %s\n" "$short_title"
  COUNT=$((COUNT + 1))

  printf "| %02d | \`%s\` | %s | %s |\n" "$IDX" "$slug" "$style" "$title" >> "${LIST_FILE}.tmp"
  printf "| %02d | \`%s\` | %s | [%s](%s/%s) |\n" \
    "$IDX" "$slug" "$style" "$title" "$RELEASE_BASE_URL" "$pdf_name" >> "$README_ROWS_FILE"
done

mv "${LIST_FILE}.tmp" "$LIST_FILE"

if [[ -f "$README" ]]; then
  BEGIN_MARK="<!-- papers-index:begin -->"
  END_MARK="<!-- papers-index:end -->"

  {
    echo "$BEGIN_MARK"
    echo "## Papers Index"
    echo ""
    echo "| # | Slug | Style | Title |"
    echo "|---|------|-------|-------|"
    cat "$README_ROWS_FILE"
    echo "$END_MARK"
  } > "${README_ROWS_FILE}.block"

  if grep -qF "$BEGIN_MARK" "$README" && grep -qF "$END_MARK" "$README"; then
    python3 - "$README" "${README_ROWS_FILE}.block" "$BEGIN_MARK" "$END_MARK" <<'PYEOF'
import sys
readme_path, block_path, begin_mark, end_mark = sys.argv[1:5]
readme = open(readme_path, encoding="utf-8").read()
block = open(block_path, encoding="utf-8").read().rstrip("\n")
start = readme.index(begin_mark)
end = readme.index(end_mark) + len(end_mark)
readme = readme[:start] + block + readme[end:]
open(readme_path, "w", encoding="utf-8").write(readme)
PYEOF
  else
    {
      cat "$README"
      echo ""
      cat "${README_ROWS_FILE}.block"
    } > "${README}.tmp"
    mv "${README}.tmp" "$README"
  fi

  rm -f "${README_ROWS_FILE}.block"
fi
rm -f "$README_ROWS_FILE"

echo -e "  ──────────────────────────────────────────────────────────────────────"
echo -e "  ${COUNT} paper(s) total"
echo ""
echo -e "  ${CYAN}Build one:${RESET}    make paper PAPER=<slug|#>"
echo -e "  ${CYAN}Build all:${RESET}    make build"
echo -e "  ${CYAN}Export md:${RESET}    make export PAPER=<slug|#>"
echo -e "  ${CYAN}New paper:${RESET}    make new-paper SLUG=<slug> STYLE=<style>"
echo -e "  ${CYAN}Delete:${RESET}       make delete-paper PAPER=<slug|#>"
echo -e "  ${CYAN}Styles:${RESET}       personal | single-column | two-column | academic | ieee | journal"
echo ""
echo -e "  ${GREY}papers/LIST_OF_PAPERS.md and README.md Papers Index updated.${RESET}"
echo ""