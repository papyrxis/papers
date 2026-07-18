#!/usr/bin/env bash
# Usage:
#   bash scripts/build-resume.sh <lang|#>           Build one resume
#   bash scripts/build-resume.sh <lang|#> --watch   Watch mode
#   bash scripts/build-resume.sh all                Build every resume

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$ROOT/build"
source "$SCRIPT_DIR/lib/resolve-resume.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; RESET='\033[0m'

log()     { echo -e "${BLUE}[resume:build]${RESET} $*"; }
success() { echo -e "${GREEN}[resume:build]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[resume:build]${RESET} $*"; }
die()     { echo -e "${RED}[resume:build]${RESET} $*" >&2; exit 1; }

usage() { echo "Usage: $(basename "$0") <lang|#|all> [--watch]" >&2; exit 1; }

[[ $# -ge 1 ]] || usage
INPUT="$1"
if [[ "$INPUT" != "all" ]]; then
  LANG="$(resolve_resume "$ROOT" "$INPUT")" || exit 1
fi
WATCH=false
[[ "${2:-}" == "--watch" ]] && WATCH=true

build_one() {
  local lang="$1"
  local conf="$ROOT/configs/resumes/${lang}.conf"
  local resume_dir="$ROOT/resumes/${lang}"

  [[ -f "$conf" ]]       || die "unknown resume lang '$lang' (no $conf)"
  [[ -d "$resume_dir" ]] || die "resume directory not found: $resume_dir"
  [[ -f "$resume_dir/resume.tex" ]] || die "resume.tex not found in $resume_dir"

  source <(tr -d '\r' < "$conf")

  local engine="${ENGINE:-xelatex}"
  local out_name="${OUTPUT_NAME:-Mahdi-Mamashli-Resume}"

  log "[$lang] compiling with $engine..."
  mkdir -p "$BUILD_DIR/resumes/$lang"

  (
    cd "$resume_dir"
    "$engine" \
      -interaction=nonstopmode \
      -output-directory="$BUILD_DIR/resumes/$lang" \
      resume.tex 2>&1 \
      | grep -E "^(! |l\.|.*Error|.*Warning)" || true
  )

  local src="$BUILD_DIR/resumes/$lang/resume.pdf"
  local dst="$BUILD_DIR/${out_name}.pdf"

  [[ -f "$src" ]] || die "[$lang] build finished but $src not found — check $BUILD_DIR/resumes/$lang/resume.log"
  cp "$src" "$dst"

  success "[$lang] done → build/${out_name}.pdf"
}

watch_one() {
  local lang="$1"
  local resume_dir="$ROOT/resumes/${lang}"
  log "watch mode on resumes/$lang — Ctrl+C to stop"
  build_one "$lang" || true

  get_sum() {
    find "$resume_dir" -type f \( -name "*.tex" \) \
      -exec md5sum {} \; 2>/dev/null | md5sum | cut -d' ' -f1
  }

  local last; last="$(get_sum)"
  while true; do
    sleep 2
    local cur; cur="$(get_sum)"
    if [[ "$cur" != "$last" ]]; then
      log "change detected, rebuilding..."
      build_one "$lang" || true
      last="$cur"
    fi
  done
}

case "${INPUT}" in
  all)
    PASSED=(); FAILED=()
    for conf in "$ROOT"/configs/resumes/*.conf; do
      [[ -f "$conf" ]] || continue
      l="$(basename "$conf" .conf)"
      if build_one "$l"; then PASSED+=("$l"); else FAILED+=("$l"); fi
    done
    echo ""
    success "Build summary: ${#PASSED[@]} passed, ${#FAILED[@]} failed"
    for l in "${PASSED[@]}"; do echo -e "  ${GREEN}✓${RESET} $l"; done
    for l in "${FAILED[@]}"; do echo -e "  ${RED}✗${RESET} $l"; done
    [[ ${#FAILED[@]} -eq 0 ]] || exit 1
    ;;
  *)
    if [[ "$WATCH" == "true" ]]; then
      watch_one "$LANG"
    else
      build_one "$LANG"
    fi
    ;;
esac
