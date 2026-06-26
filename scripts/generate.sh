#!/usr/bin/env bash
# Usage: bash scripts/generate.sh <slug>

set -euo pipefail
die() { echo "error: $*" >&2; exit 1; }

[[ $# -eq 1 ]] || { echo "Usage: $(basename "$0") <slug>" >&2; exit 1; }

SLUG="$1"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="$ROOT/configs/papers/${SLUG}.conf"
TEMPLATE="$ROOT/main.tex"
PAPER_DIR="$ROOT/papers/${SLUG}"

[[ -f "$CONF" ]]      || die "no config for paper '$SLUG' (expected $CONF)"
[[ -f "$TEMPLATE" ]]  || die "template not found ($TEMPLATE)"
[[ -d "$PAPER_DIR" ]] || die "paper directory not found ($PAPER_DIR)"

source <(tr -d '\r' < "$CONF")

: "${PAPER_TITLE:?PAPER_TITLE not set in $CONF}"
: "${PAPER_STYLE:?PAPER_STYLE not set in $CONF}"
: "${SECTIONS:?SECTIONS not set in $CONF}"

# Validate style
case "${PAPER_STYLE}" in
  personal|single-column|two-column|academic|ieee|journal) ;;
  *) die "Unknown PAPER_STYLE '${PAPER_STYLE}'. Valid: personal | single-column | two-column | academic | ieee | journal" ;;
esac

PAPER_AUTHOR="${PAPER_AUTHOR:-Mahdi Mamashli (Genix)}"
PAPER_EMAIL="${PAPER_EMAIL:-bitsgenix@gmail.com}"
PDF_TITLE="${PDF_TITLE:-$PAPER_TITLE}"
PDF_SUBJECT="${PDF_SUBJECT:-}"
PDF_KEYWORDS="${PDF_KEYWORDS:-}"
PAPER_FONTSIZE="${PAPER_FONTSIZE:-12pt}"
PAPER_YEAR="${PAPER_YEAR:-$(date -u '+%Y')}"
BIB_FILE="${BIB_FILE:-references/paper.bib}"
TOC="${TOC:-false}"
BACKMATTER="${BACKMATTER:-(backmatter/bibliography)}"

PXIS_PATH="../../.pxis"
CONFIGS_PATH="../../configs"

OUTPUT="$PAPER_DIR/main.tex"

# Build \input{...} blocks
SECTIONS_BLOCK=""
for s in "${SECTIONS[@]}"; do
  SECTIONS_BLOCK+="\\input{${s}}"$'\n\n'
done

BACKMATTER_BLOCK=""
for b in "${BACKMATTER[@]}"; do
  BACKMATTER_BLOCK+="\\input{${b}}"$'\n'
done

TOCBLOCK=""
if [[ "$TOC" == "true" ]]; then
  TOCBLOCK="\\tableofcontents"$'\n'"\\newpage"
fi

escape_sed() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/[\/&]/\\&/g'
}

T_PAPER_TITLE="$(escape_sed "$PAPER_TITLE")"
T_PAPER_AUTHOR="$(escape_sed "$PAPER_AUTHOR")"
T_PAPER_EMAIL="$(escape_sed "$PAPER_EMAIL")"
T_PAPER_STYLE="$(escape_sed "$PAPER_STYLE")"
T_PAPER_YEAR="$(escape_sed "$PAPER_YEAR")"
T_PAPER_FONTSIZE="$(escape_sed "$PAPER_FONTSIZE")"
T_PDF_TITLE="$(escape_sed "$PDF_TITLE")"
T_PDF_SUBJECT="$(escape_sed "$PDF_SUBJECT")"
T_PDF_KEYWORDS="$(escape_sed "$PDF_KEYWORDS")"
T_BIB_PATH="$(escape_sed "$BIB_FILE")"
T_PXIS_PATH="$(escape_sed "$PXIS_PATH")"
T_CONFIGS_PATH="$(escape_sed "$CONFIGS_PATH")"

{
  while IFS='' read -r line || [[ -n "$line" ]]; do
    case "$line" in
      *'@SECTIONS@'*)
        printf '%s' "$SECTIONS_BLOCK"
        ;;
      *'@BACKMATTER@'*)
        printf '%s' "$BACKMATTER_BLOCK"
        ;;
      *'@TOCBLOCK@'*)
        printf '%s\n' "$TOCBLOCK"
        ;;
      *)
        printf '%s\n' "$line" \
          | sed \
              -e "s/@PAPER_TITLE@/${T_PAPER_TITLE}/g" \
              -e "s/@PAPER_AUTHOR@/${T_PAPER_AUTHOR}/g" \
              -e "s/@PAPER_EMAIL@/${T_PAPER_EMAIL}/g" \
              -e "s/@PAPER_STYLE@/${T_PAPER_STYLE}/g" \
              -e "s/@PAPER_YEAR@/${T_PAPER_YEAR}/g" \
              -e "s/@PAPER_FONTSIZE@/${T_PAPER_FONTSIZE}/g" \
              -e "s/@PDF_TITLE@/${T_PDF_TITLE}/g" \
              -e "s/@PDF_SUBJECT@/${T_PDF_SUBJECT}/g" \
              -e "s/@PDF_KEYWORDS@/${T_PDF_KEYWORDS}/g" \
              -e "s/@BIB_PATH@/${T_BIB_PATH}/g" \
              -e "s/@PXIS_PATH@/${T_PXIS_PATH}/g" \
              -e "s/@CONFIGS_PATH@/${T_CONFIGS_PATH}/g"
        ;;
    esac
  done < "$TEMPLATE"
} > "$OUTPUT"

echo "generated ${OUTPUT#$ROOT/}"