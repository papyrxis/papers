#!/usr/bin/env bash
# Usage:
#   bash scripts/resume.sh                   Interactive menu
#   bash scripts/resume.sh <command> [args]  Direct command

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib/resolve-resume.sh"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
  echo -e "${BOLD}${BLUE}  ║${RESET}  ${BOLD}Resume${RESET} — Mahdi Mamashli (Genix)  ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}  ╚══════════════════════════════════════╝${RESET}"
  echo ""
}

# ── Lang description ─────────────────────────────────────────────────────────
lang_desc() {
  case "$1" in
    en) echo "English  — xelatex, Charter, single-page" ;;
    fa) echo "فارسی    — xelatex, Vazirmatn, RTL (Awesome-CV)" ;;
    *)  echo "Unknown" ;;
  esac
}

# ── List all resumes ──────────────────────────────────────────────────────────
cmd_list() {
  echo ""
  echo -e "${BOLD}  Resumes — Genix${RESET}"
  echo -e "  ──────────────────────────────────────────────────────────────────"
  printf "  %-4s  %-6s  %-8s  %-28s  %s\n" "#" "Lang" "Built" "Output name" "Description"
  echo -e "  ──────────────────────────────────────────────────────────────────"

  local idx=0
  for conf in "$ROOT"/configs/resumes/*.conf; do
    [[ -f "$conf" ]] || continue
    idx=$((idx + 1))
    local lang; lang="$(basename "$conf" .conf)"

    RESUME_LANG=""
    OUTPUT_NAME=""
    source <(tr -d '\r' < "$conf") 2>/dev/null || true

    local out="${OUTPUT_NAME:-resume}"
    local desc; desc="$(lang_desc "$lang")"

    local built_str
    if [[ -f "$ROOT/build/${out}.pdf" ]]; then
      built_str="${GREEN}yes${RESET}"
    else
      built_str="${RED}no${RESET}"
    fi

    printf "  %-4s  %-6s  " "[$idx]" "$lang"
    echo -en "$built_str"
    printf "     %-28s  %s\n" "${out}.pdf" "$desc"
  done

  echo -e "  ──────────────────────────────────────────────────────────────────"
  echo ""
  echo -e "  ${CYAN}Build one:${RESET}   bash scripts/resume.sh build <lang|#>"
  echo -e "  ${CYAN}Build all:${RESET}   bash scripts/resume.sh build all"
  echo -e "  ${CYAN}Rename:${RESET}      Edit OUTPUT_NAME in configs/resumes/<lang>.conf"
  echo ""
}

# ── Build ─────────────────────────────────────────────────────────────────────
cmd_build() {
  local target="${1:-}"

  if [[ -z "$target" ]]; then
    echo ""
    echo -e "${BOLD}  Build Resume${RESET}"
    echo ""
    cmd_list

    echo -e "  ${CYAN}Which resume?${RESET}"
    echo -e "  Enter a lang code (en, fa), a number (#), or 'all'."
    echo ""
    read -rp "  Choice: " target
    [[ -z "$target" ]] && error "No choice made."
  fi

  bash "$SCRIPT_DIR/build-resume.sh" "$target"
}

# ── Watch ─────────────────────────────────────────────────────────────────────
cmd_watch() {
  local target="${1:-}"

  if [[ -z "$target" ]]; then
    cmd_list
    read -rp "  Lang to watch (en, fa, #): " target
    [[ -z "$target" ]] && error "No choice made."
  fi

  bash "$SCRIPT_DIR/build-resume.sh" "$target" --watch
}

# ── Clean ─────────────────────────────────────────────────────────────────────
cmd_clean() {
  local input="${1:-}"

  if [[ -n "$input" ]]; then
    local lang
    lang="$(resolve_resume "$ROOT" "$input")" || exit 1
    log "Cleaning build artifacts for: $lang"

    rm -rf "$ROOT/build/resumes/$lang"

    # Remove the named output PDF if it matches
    local conf="$ROOT/configs/resumes/${lang}.conf"
    if [[ -f "$conf" ]]; then
      OUTPUT_NAME=""
      source <(tr -d '\r' < "$conf") 2>/dev/null || true
      [[ -n "$OUTPUT_NAME" ]] && rm -f "$ROOT/build/${OUTPUT_NAME}.pdf"
    fi

    find "$ROOT/resumes/$lang" -type f \
      \( -name "*.aux" -o -name "*.log" -o -name "*.out" \
         -o -name "*.toc" -o -name "*.synctex.gz" \
         -o -name "*.fdb_latexmk" -o -name "*.fls" \
      \) -delete 2>/dev/null || true

    success "Cleaned $lang"
  else
    log "Cleaning all resume build artifacts..."
    rm -rf "$ROOT/build/resumes"
    find "$ROOT/resumes" -type f \
      \( -name "*.aux" -o -name "*.log" -o -name "*.out" \
         -o -name "*.toc" -o -name "*.synctex.gz" \
         -o -name "*.fdb_latexmk" -o -name "*.fls" \
      \) -delete 2>/dev/null || true
    # Remove named PDFs from build root
    for conf in "$ROOT"/configs/resumes/*.conf; do
      [[ -f "$conf" ]] || continue
      OUTPUT_NAME=""
      source <(tr -d '\r' < "$conf") 2>/dev/null || true
      [[ -n "$OUTPUT_NAME" ]] && rm -f "$ROOT/build/${OUTPUT_NAME}.pdf"
    done
    success "All resume artifacts cleaned"
  fi
}

# ── Rename output PDF ─────────────────────────────────────────────────────────
cmd_rename() {
  local input="${1:-}"
  local new_name="${2:-}"

  if [[ -z "$input" ]]; then
    cmd_list
    read -rp "  Which resume to rename? (lang|#): " input
    [[ -z "$input" ]] && error "No choice made."
  fi

  local lang
  lang="$(resolve_resume "$ROOT" "$input")" || exit 1
  local conf="$ROOT/configs/resumes/${lang}.conf"

  OUTPUT_NAME=""
  source <(tr -d '\r' < "$conf") 2>/dev/null || true
  local current_name="${OUTPUT_NAME:-resume}"

  if [[ -z "$new_name" ]]; then
    echo ""
    echo -e "  ${CYAN}Current output name:${RESET} ${current_name}.pdf"
    echo -e "  Enter new name ${DIM}(without .pdf)${RESET}:"
    read -rp "  New name: " new_name
    [[ -z "$new_name" ]] && error "Name cannot be empty."
  fi

  # Strip .pdf if user typed it
  new_name="${new_name%.pdf}"

  # Update the conf file
  if grep -q '^OUTPUT_NAME=' "$conf"; then
    sed -i "s|^OUTPUT_NAME=.*|OUTPUT_NAME=\"${new_name}\"|" "$conf"
  else
    echo "OUTPUT_NAME=\"${new_name}\"" >> "$conf"
  fi

  success "[$lang] OUTPUT_NAME set to: ${new_name}.pdf"
  info "Next build will produce: build/${new_name}.pdf"
}

# ── Help ──────────────────────────────────────────────────────────────────────
cmd_help() {
  echo ""
  echo -e "${BOLD}  resume CLI — Genix${RESET}"
  echo -e "  ─────────────────────────────────────────────────────────────────"
  echo ""
  echo -e "  ${CYAN}Usage:${RESET}"
  echo -e "    bash scripts/resume.sh                   Interactive menu"
  echo -e "    bash scripts/resume.sh <command> [args]  Direct command"
  echo ""
  echo -e "  Anywhere a <lang> is expected, its number from ${BOLD}list${RESET} works too."
  echo ""
  echo -e "  ${CYAN}Commands:${RESET}"
  echo -e "    ${BOLD}list${RESET}                         List all resumes & build status"
  echo -e "    ${BOLD}build${RESET}  <lang|#|all>          Build resume(s) to PDF"
  echo -e "    ${BOLD}watch${RESET}  <lang|#>              Auto-rebuild on file change"
  echo -e "    ${BOLD}rename${RESET} <lang|#> [new-name]   Set output PDF name"
  echo -e "    ${BOLD}clean${RESET}  [lang|#]              Remove build artifacts"
  echo -e "    ${BOLD}help${RESET}                         Show this help"
  echo ""
  echo -e "  ${CYAN}Examples:${RESET}"
  echo -e "    bash scripts/resume.sh build en"
  echo -e "    bash scripts/resume.sh build fa"
  echo -e "    bash scripts/resume.sh build 1"
  echo -e "    bash scripts/resume.sh build all"
  echo -e "    bash scripts/resume.sh watch en"
  echo -e "    bash scripts/resume.sh rename en Mahdi-Mamashli-Resume-2026"
  echo -e "    bash scripts/resume.sh clean fa"
  echo ""
  echo -e "  ${CYAN}Makefile shortcuts:${RESET}"
  echo -e "    make resume       LANG=<lang|#>           Build one"
  echo -e "    make resume-all                           Build all"
  echo -e "    make resume-watch LANG=<lang|#>           Watch mode"
  echo -e "    make resume-clean [LANG=<lang|#>]         Clean artifacts"
  echo ""
  echo -e "  ${CYAN}Output PDF name:${RESET}"
  echo -e "    Edit OUTPUT_NAME in configs/resumes/<lang>.conf"
  echo -e "    or run: bash scripts/resume.sh rename <lang> <new-name>"
  echo ""
}

# ── Interactive menu ──────────────────────────────────────────────────────────
interactive_menu() {
  print_banner
  cmd_list
  echo -e "  ${CYAN}What would you like to do?${RESET}"
  echo ""
  echo -e "  ${BOLD}[1]${RESET}  build   — Build a resume to PDF"
  echo -e "  ${BOLD}[2]${RESET}  build all — Build all resumes"
  echo -e "  ${BOLD}[3]${RESET}  watch   — Watch mode (auto-rebuild)"
  echo -e "  ${BOLD}[4]${RESET}  rename  — Change output PDF name"
  echo -e "  ${BOLD}[5]${RESET}  clean   — Remove build artifacts"
  echo -e "  ${BOLD}[6]${RESET}  list    — Show resume list"
  echo -e "  ${BOLD}[q]${RESET}  quit"
  echo ""
  read -rp "  Choice: " choice

  case "$choice" in
    1|build)    cmd_build ;;
    2)          cmd_build all ;;
    3|watch)    cmd_watch ;;
    4|rename)   cmd_rename ;;
    5|clean)    cmd_clean ;;
    6|list)     cmd_list ;;
    q|quit)     echo ""; dim "  Bye!"; echo ""; exit 0 ;;
    *)          warn "Unknown choice: $choice"; interactive_menu ;;
  esac
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
CMD="${1:-}"
shift || true

case "$CMD" in
  build)   cmd_build  "$@" ;;
  watch)   cmd_watch  "$@" ;;
  rename)  cmd_rename "$@" ;;
  clean)   cmd_clean  "$@" ;;
  list)    cmd_list ;;
  help|-h|--help) cmd_help ;;
  "")      interactive_menu ;;
  *)       error "Unknown command: $CMD. Run: bash scripts/resume.sh help" ;;
esac
