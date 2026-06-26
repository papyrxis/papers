#!/usr/bin/env bash
# scripts/list-papers.sh — List all papers with status and style

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$ROOT/build"

BLUE='\033[0;34m'; CYAN='\033[0;36m'; GREEN='\033[0;32m'
GREY='\033[0;37m'; BOLD='\033[1m'; RESET='\033[0m'

echo ""
echo -e "${BOLD}  Papers — Genix${RESET}"
echo -e "  ─────────────────────────────────────────────────────────"
printf "  %-44s %-14s %s\n" "Slug" "Style" "Built"
echo -e "  ─────────────────────────────────────────────────────────"

COUNT=0

for conf in "$ROOT"/configs/papers/*.conf; do
  [[ -f "$conf" ]] || continue
  slug="$(basename "$conf" .conf)"

  PAPER_STYLE=""
  # shellcheck disable=SC1090
  source <(tr -d '\r' < "$conf") 2>/dev/null || true
  style="${PAPER_STYLE:-—}"

  built="${GREY}no${RESET}"
  if find "$BUILD_DIR" -maxdepth 1 -name "*.pdf" 2>/dev/null | grep -q .; then
    built="${GREEN}yes${RESET}"
  fi

  printf "  %-44s %-14s " "$slug" "$style"
  echo -e "$built"
  COUNT=$((COUNT + 1))
done

echo -e "  ─────────────────────────────────────────────────────────"
echo -e "  ${COUNT} paper(s) total"
echo ""
echo -e "  ${CYAN}Build one:${RESET}    make paper PAPER=<slug>"
echo -e "  ${CYAN}Build all:${RESET}    make build"
echo -e "  ${CYAN}New paper:${RESET}    make new-paper SLUG=<slug> STYLE=<style>"
echo ""