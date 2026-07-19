#!/usr/bin/env bash
# Usage:
#   bash scripts/build.sh <slug|#>            Generate + build one paper
#   bash scripts/build.sh <slug|#> --watch    Watch mode
#   bash scripts/build.sh all                  Build every paper with a .conf
#
# <slug|#> accepts either the full paper slug (01-the-nature-of-data)
# or its position in `make list` (1, 2, 3, ...).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GENERATE="$SCRIPT_DIR/generate.sh"
BUILD_DIR="$ROOT/build"
source "$SCRIPT_DIR/lib/resolve-paper.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; RESET='\033[0m'

log()     { echo -e "${BLUE}[build]${RESET} $*"; }
success() { echo -e "${GREEN}[build]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[build]${RESET} $*"; }
die()     { echo -e "${RED}[build]${RESET} $*" >&2; exit 1; }

usage() { echo "Usage: $(basename "$0") <slug|#|all> [--watch]" >&2; exit 1; }

[[ $# -ge 1 ]] || usage
SLUG="$1"
if [[ "$SLUG" != "all" ]]; then
  SLUG="$(resolve_paper "$ROOT" "$SLUG")" || exit 1
fi
WATCH=false
[[ "${2:-}" == "--watch" ]] && WATCH=true

ensure_pxis() {
  if [[ ! -f "$ROOT/.pxis/preset.tex" ]]; then
    warn ".pxis/preset.tex missing — running sync..."
    if [[ -d "$ROOT/workspace" ]]; then
      bash "$ROOT/workspace/src/sync.sh"
    else
      die ".pxis/preset.tex missing and no workspace/ submodule found. Run: make sync"
    fi
  fi
}

build_one() {
  local slug="$1"
  local conf="$ROOT/configs/papers/${slug}.conf"
  local paper_dir="$ROOT/papers/${slug}"

  [[ -f "$conf" ]] || die "unknown paper '$slug' (no $conf)"
  [[ -d "$paper_dir" ]] || die "paper directory not found: $paper_dir"

  log "[$slug] generate main.tex"
  bash "$GENERATE" "$slug"

  source <(tr -d '\r' < "$conf")
  local engine="${ENGINE:-pdflatex}"
  local bibtex="${BIBTEX:-biber}"

  log "[$slug] compile ($engine, 2 passes + $bibtex)"
  mkdir -p "$BUILD_DIR/$slug"

  export TEXINPUTS=".:$paper_dir:$ROOT:$ROOT/workspace::"
  export PROJECT_VERSION="$(git -C "$ROOT" describe --tags --always --dirty 2>/dev/null || echo dev)"
  export BUILD_DATE="$(date -u '+%Y-%m-%d %H:%M UTC')"

  (
    cd "$paper_dir"

    "$engine" -interaction=nonstopmode -output-directory="$BUILD_DIR/$slug" main.tex >/dev/null 2>&1 || {
      echo ""
      die "[$slug] pdflatex pass 1 failed — see $BUILD_DIR/$slug/main.log"
    }

    if grep -q '\\addbibresource\|\\printbibliography' main.tex; then
      if [[ ! -f "$BUILD_DIR/$slug/main.bcf" ]]; then
        die "[$slug] main.bcf not found after pdflatex pass 1 — see $BUILD_DIR/$slug/main.log"
      fi
      "$bibtex" "$BUILD_DIR/$slug/main"
      "$engine" -interaction=nonstopmode -output-directory="$BUILD_DIR/$slug" main.tex >/dev/null 2>&1 || true
    fi

    "$engine" -interaction=nonstopmode -output-directory="$BUILD_DIR/$slug" main.tex >/dev/null 2>&1 || true
  )

  local year; year="$(date -u '+%Y')"
  local safe_title; safe_title="$(echo "${PAPER_TITLE:-$slug}" | tr ' ' '_' | tr -cd 'A-Za-z0-9_-')"
  local out_basename="${year}_Genix_${safe_title}"
  local src="$BUILD_DIR/$slug/main.pdf"
  local dst="$BUILD_DIR/${out_basename}.pdf"

  [[ -f "$src" ]] || die "[$slug] build finished but $src not found — check $BUILD_DIR/$slug/main.log"
  cp "$src" "$dst"

  success "[$slug] done -> build/${out_basename}.pdf"
}

watch_one() {
  local slug="$1"
  local paper_dir="$ROOT/papers/${slug}"
  log "watch mode on papers/$slug — Ctrl+C to stop"
  build_one "$slug" || true

  get_sum() {
    find "$paper_dir" "$ROOT/configs/papers/${slug}.conf" -type f \
      \( -name "*.tex" -o -name "*.bib" -o -name "*.conf" \) \
      -exec md5sum {} \; 2>/dev/null | md5sum | cut -d' ' -f1
  }

  local last; last="$(get_sum)"
  while true; do
    sleep 2
    local cur; cur="$(get_sum)"
    if [[ "$cur" != "$last" ]]; then
      log "change detected, rebuilding..."
      build_one "$slug" || true
      last="$cur"
    fi
  done
}

ensure_pxis

case "$SLUG" in
  all)
    PASSED=(); FAILED=()
    for conf in "$ROOT"/configs/papers/*.conf; do
      [[ -f "$conf" ]] || continue
      s="$(basename "$conf" .conf)"
      if build_one "$s"; then PASSED+=("$s"); else FAILED+=("$s"); fi
    done
    echo ""
    success "Build summary: ${#PASSED[@]} passed, ${#FAILED[@]} failed"
    for s in "${PASSED[@]}"; do echo -e "  ${GREEN}✓${RESET} $s"; done
    for s in "${FAILED[@]}"; do echo -e "  ${RED}✗${RESET} $s"; done
    [[ ${#FAILED[@]} -eq 0 ]] || exit 1
    ;;
  *)
    if [[ "$WATCH" == "true" ]]; then
      watch_one "$SLUG"
    else
      build_one "$SLUG"
    fi
    ;;
esac