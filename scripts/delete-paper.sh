#!/usr/bin/env bash
# Usage: bash scripts/delete-paper.sh <slug|#> [--yes]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib/resolve-paper.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; RESET='\033[0m'

log()     { echo -e "${BLUE}[delete-paper]${RESET} $*"; }
success() { echo -e "${GREEN}[delete-paper]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[delete-paper]${RESET} $*"; }
die()     { echo -e "${RED}[delete-paper]${RESET} $*" >&2; exit 1; }

usage() { echo "Usage: $(basename "$0") <slug|#> [--yes]" >&2; exit 1; }

[[ $# -ge 1 ]] || usage
SLUG="$(resolve_paper "$ROOT" "$1")" || exit 1
ASSUME_YES=false
[[ "${2:-}" == "--yes" || "${2:-}" == "-y" ]] && ASSUME_YES=true

PAPER_DIR="$ROOT/papers/$SLUG"
CONF="$ROOT/configs/papers/${SLUG}.conf"

if [[ ! -d "$PAPER_DIR" && ! -f "$CONF" ]]; then
  die "nothing to delete: no papers/$SLUG and no configs/papers/${SLUG}.conf"
fi

PAPER_TITLE=""
[[ -f "$CONF" ]] && source <(tr -d '\r' < "$CONF") 2>/dev/null || true

echo ""
warn "This will permanently delete:"
[[ -d "$PAPER_DIR" ]] && echo "    papers/$SLUG/"
[[ -f "$CONF" ]]      && echo "    configs/papers/${SLUG}.conf"
[[ -d "$ROOT/build/$SLUG" ]] && echo "    build/$SLUG/"
echo "    its row in papers/LIST_OF_PAPERS.md"
[[ -f "$ROOT/README.md" ]] && grep -q "\`$SLUG\`" "$ROOT/README.md" 2>/dev/null && echo "    its row in README.md"
echo ""

if [[ "$ASSUME_YES" != "true" ]]; then
  read -rp "  Type the slug to confirm (${SLUG}): " confirm
  [[ "$confirm" == "$SLUG" ]] || die "confirmation did not match — nothing deleted"
fi

rm -rf "$PAPER_DIR"
rm -f "$CONF"
rm -rf "$ROOT/build/$SLUG"

if [[ -n "${PAPER_TITLE:-}" ]]; then
  safe_title="$(echo "$PAPER_TITLE" | tr ' ' '_' | tr -cd 'A-Za-z0-9_-')"
  find "$ROOT/build" -maxdepth 1 -name "*${safe_title}*.pdf" -delete 2>/dev/null || true
fi

log "Removed papers/$SLUG, its config, and its build artifacts"

bash "$SCRIPT_DIR/list-papers.sh" >/dev/null

success "Deleted: $SLUG"
echo ""
echo "  Remaining papers have been renumbered — run 'make list' to see them."
echo ""