#!/usr/bin/env bash
# Usage:
#   bash scripts/papers.sh
#   bash scripts/papers.sh <command> [args...]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
log()     { echo -e "${BLUE}▶${RESET} $*"; }
success() { echo -e "${GREEN}✓${RESET} $*"; }
warn()    { echo -e "${YELLOW}⚠${RESET} $*"; }
error()   { echo -e "${RED}✗${RESET} $*" >&2; exit 1; }
info()    { echo -e "${CYAN}ℹ${RESET} $*"; }
dim()     { echo -e "${DIM}$*${RESET}"; }

# ── Banner ────────────────────────────────────────────────────────────────────
print_banner() {
  echo ""
  echo -e "${BOLD}${BLUE}  ╔══════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${BLUE}  ║${RESET}  ${BOLD}Papers${RESET} — Mahdi Mamashli (Genix)  ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}  ╚══════════════════════════════════════╝${RESET}"
  echo ""
}

# ── Style descriptions ────────────────────────────────────────────────────────
style_desc() {
  case "$1" in
    personal)      echo "Personal essay / technical note (Charter, branded footer)" ;;
    single-column) echo "Clean single-column (Charter, minimal chrome)" ;;
    two-column)    echo "Two-column general layout (Charter, accent header)" ;;
    academic)      echo "Formal research paper (Times, theorems, author footer, TOC)" ;;
    ieee)          echo "IEEE conference format (Times, two-column, uppercase sections)" ;;
    journal)       echo "Journal submission (Palatino, running header, full footer, TOC)" ;;
    *)             echo "Unknown style" ;;
  esac
}

# ── List all papers ───────────────────────────────────────────────────────────
cmd_list() {
  echo ""
  echo -e "${BOLD}  Papers — Genix${RESET}"
  echo -e "  ──────────────────────────────────────────────────────────────────"
  printf "  %-46s %-14s %-6s  %s\n" "Slug" "Style" "Built" "Title"
  echo -e "  ──────────────────────────────────────────────────────────────────"

  COUNT=0

  for conf in "$ROOT"/configs/papers/*.conf; do
    [[ -f "$conf" ]] || continue
    slug="$(basename "$conf" .conf)"

    PAPER_TITLE=""
    PAPER_STYLE=""
    source <(tr -d '\r' < "$conf") 2>/dev/null || true
    style="${PAPER_STYLE:-—}"
    title="${PAPER_TITLE:-}"

    built="${RED}no${RESET}"
    if find "$ROOT/build" -maxdepth 1 -name "*$(echo "$slug" | tr '-' '_' | tr '[:lower:]' '[:upper:]')*.pdf" \
         -o -name "*$(echo "$PAPER_TITLE" | tr ' ' '_' | tr -cd 'A-Za-z0-9_-')*.pdf" \
         2>/dev/null | grep -q .; then
      built="${GREEN}yes${RESET}"
    elif find "$ROOT/build" -maxdepth 1 -name "*.pdf" 2>/dev/null | grep -q .; then
      built="${YELLOW}stale${RESET}"
    fi

    short_title="${title:0:50}"
    [[ ${#title} -gt 50 ]] && short_title="${short_title}…"

    printf "  %-46s %-14s " "$slug" "$style"
    echo -en "$built"
    printf "  %s\n" "$short_title"
    COUNT=$((COUNT + 1))
  done

  echo -e "  ──────────────────────────────────────────────────────────────────"
  echo -e "  ${COUNT} paper(s) total"
  echo ""
  echo -e "  ${CYAN}Build one:${RESET}   make paper PAPER=<slug>"
  echo -e "  ${CYAN}Build all:${RESET}   make build"
  echo -e "  ${CYAN}New paper:${RESET}   make new-paper SLUG=<slug> STYLE=<style>"
  echo ""
}

# ── Show available styles ────────────────────────────────────────────────────
cmd_styles() {
  echo ""
  echo -e "${BOLD}  Available Paper Styles${RESET}"
  echo -e "  ─────────────────────────────────────────────────────────────────"
  for s in personal single-column two-column academic ieee journal; do
    printf "  ${CYAN}%-16s${RESET} %s\n" "$s" "$(style_desc "$s")"
  done
  echo ""
  echo -e "  Use: ${DIM}make new-paper SLUG=<slug> STYLE=<style>${RESET}"
  echo ""
}

# ── New paper ────────────────────────────────────────────────────────────────
cmd_new() {
  local slug="${1:-}"
  local style="${2:-}"

  if [[ -z "$slug" ]]; then
    echo ""
    echo -e "${BOLD}  New Paper${RESET}"
    echo ""
    read -rp "  Slug (e.g. 02-my-paper-title): " slug
    [[ -z "$slug" ]] && error "Slug cannot be empty."
  fi

  if [[ -z "$style" ]]; then
    echo ""
    echo -e "  ${CYAN}Available styles:${RESET}"
    for s in personal single-column two-column academic ieee journal; do
      printf "    %-16s %s\n" "$s" "$(style_desc "$s")"
    done
    echo ""
    read -rp "  Style [personal]: " style
    style="${style:-personal}"
  fi

  bash "$SCRIPT_DIR/new-paper.sh" "$slug" "$style"
}

# ── Build ────────────────────────────────────────────────────────────────────
cmd_build() {
  local target="${1:-}"

  if [[ -z "$target" ]]; then
    echo ""
    echo -e "${BOLD}  Build Paper${RESET}"
    echo ""
    cmd_list

    read -rp "  Slug to build (or 'all'): " target
    [[ -z "$target" ]] && error "Slug cannot be empty."
  fi

  bash "$SCRIPT_DIR/build.sh" "$target"
}

# ── Watch ────────────────────────────────────────────────────────────────────
cmd_watch() {
  local slug="${1:-}"

  if [[ -z "$slug" ]]; then
    cmd_list
    read -rp "  Slug to watch: " slug
    [[ -z "$slug" ]] && error "Slug cannot be empty."
  fi

  bash "$SCRIPT_DIR/build.sh" "$slug" --watch
}

# ── Clean ────────────────────────────────────────────────────────────────────
cmd_clean() {
  local slug="${1:-}"

  if [[ -n "$slug" ]]; then
    log "Cleaning build artifacts for: $slug"
    rm -rf "$ROOT/build/$slug"
    find "$ROOT/papers/$slug" -type f \
      \( -name "*.aux" -o -name "*.log" -o -name "*.out" \
         -o -name "*.toc" -o -name "*.bbl" -o -name "*.blg" \
         -o -name "*.synctex.gz" -o -name "*.fdb_latexmk" \
         -o -name "*.fls" -o -name "*.idx" -o -name "*.ilg" \
         -o -name "*.ind" -o -name "*.run.xml" -o -name "*.bcf" \
      \) -delete 2>/dev/null || true
    success "Cleaned $slug"
  else
    log "Cleaning all build artifacts..."
    bash "$SCRIPT_DIR/clean.sh"
    find "$ROOT" -type f \
      \( -name "*.aux" -o -name "*.log" -o -name "*.out" \
         -o -name "*.toc" -o -name "*.bbl" -o -name "*.blg" \
         -o -name "*.synctex.gz" -o -name "*.fdb_latexmk" \
         -o -name "*.fls" -o -name "*.idx" -o -name "*.ilg" \
         -o -name "*.ind" -o -name "*.run.xml" -o -name "*.bcf" \
      \) -delete 2>/dev/null || true
    success "All clean"
  fi
}

# ── Help ─────────────────────────────────────────────────────────────────────
cmd_help() {
  echo ""
  echo -e "${BOLD}  papers CLI — Genix${RESET}"
  echo -e "  ─────────────────────────────────────────────────────────────────"
  echo ""
  echo -e "  ${CYAN}Usage:${RESET}"
  echo -e "    bash scripts/papers.sh                  Interactive menu"
  echo -e "    bash scripts/papers.sh <command> [args]  Direct command"
  echo ""
  echo -e "  ${CYAN}Commands:${RESET}"
  echo -e "    ${BOLD}new${RESET}    <slug> [style]  Scaffold a new paper"
  echo -e "    ${BOLD}build${RESET}  <slug|all>      Build paper(s) to PDF"
  echo -e "    ${BOLD}watch${RESET}  <slug>          Auto-rebuild on file change"
  echo -e "    ${BOLD}list${RESET}                   List all papers"
  echo -e "    ${BOLD}styles${RESET}                 Show available styles"
  echo -e "    ${BOLD}clean${RESET}  [slug]          Remove build artifacts"
  echo -e "    ${BOLD}help${RESET}                   Show this help"
  echo ""
  echo -e "  ${CYAN}Examples:${RESET}"
  echo -e "    bash scripts/papers.sh new 02-type-theory academic"
  echo -e "    bash scripts/papers.sh build 01-function-theoretic-definition-of-data"
  echo -e "    bash scripts/papers.sh build all"
  echo -e "    bash scripts/papers.sh watch 02-type-theory"
  echo -e "    bash scripts/papers.sh clean 01-function-theoretic-definition-of-data"
  echo ""
  echo -e "  ${CYAN}Makefile shortcuts:${RESET}"
  echo -e "    make new-paper SLUG=<slug> STYLE=<style>"
  echo -e "    make paper     PAPER=<slug>"
  echo -e "    make build"
  echo -e "    make list"
  echo -e "    make clean"
  echo ""
}

# ── Interactive menu ──────────────────────────────────────────────────────────
interactive_menu() {
  print_banner
  echo -e "  ${CYAN}What would you like to do?${RESET}"
  echo ""
  echo -e "  ${BOLD}[1]${RESET}  new      — Scaffold a new paper"
  echo -e "  ${BOLD}[2]${RESET}  build    — Build a paper to PDF"
  echo -e "  ${BOLD}[3]${RESET}  watch    — Watch mode (auto-rebuild)"
  echo -e "  ${BOLD}[4]${RESET}  list     — List all papers"
  echo -e "  ${BOLD}[5]${RESET}  styles   — Show available styles"
  echo -e "  ${BOLD}[6]${RESET}  clean    — Remove build artifacts"
  echo -e "  ${BOLD}[q]${RESET}  quit"
  echo ""
  read -rp "  Choice: " choice

  case "$choice" in
    1|new)    cmd_new ;;
    2|build)  cmd_build ;;
    3|watch)  cmd_watch ;;
    4|list)   cmd_list ;;
    5|styles) cmd_styles ;;
    6|clean)  cmd_clean ;;
    q|quit)   echo ""; dim "  Bye!"; echo ""; exit 0 ;;
    *)        warn "Unknown choice: $choice"; interactive_menu ;;
  esac
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
CMD="${1:-}"
shift || true

case "$CMD" in
  new)    cmd_new    "$@" ;;
  build)  cmd_build  "$@" ;;
  watch)  cmd_watch  "$@" ;;
  list)   cmd_list ;;
  styles) cmd_styles ;;
  clean)  cmd_clean  "$@" ;;
  help|-h|--help) cmd_help ;;
  "")     interactive_menu ;;
  *)      error "Unknown command: $CMD. Run: bash scripts/papers.sh help" ;;
esac