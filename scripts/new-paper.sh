#!/usr/bin/env bash
# scripts/new-paper.sh — Scaffold a new paper.
# Usage:
#   bash scripts/new-paper.sh <slug> [style]
# Examples:
#   bash scripts/new-paper.sh 02-type-confusion-taxonomy academic
#   bash scripts/new-paper.sh 03-why-endianness-matters personal

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; RESET='\033[0m'

log()     { echo -e "${BLUE}[new-paper]${RESET} $*"; }
success() { echo -e "${GREEN}[new-paper]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[new-paper]${RESET} $*"; }
error()   { echo -e "${RED}[new-paper]${RESET} $*" >&2; exit 1; }

SLUG="${1:-}"
STYLE="${2:-personal}"
YEAR="$(date -u '+%Y')"

[[ -z "$SLUG" ]] && error "Usage: $0 <slug> [style]"

case "$STYLE" in
  personal|academic|ieee|two-column|single-column) ;;
  *) error "Unknown style '$STYLE'. Options: personal | academic | ieee | two-column | single-column" ;;
esac

PAPER_DIR="$ROOT/papers/$SLUG"
CONF="$ROOT/configs/papers/${SLUG}.conf"

[[ -d "$PAPER_DIR" ]] && error "Paper already exists: papers/$SLUG"
[[ -f "$CONF" ]]      && error "Config already exists: configs/papers/${SLUG}.conf"

# Derive a human-readable title from the slug: strip leading "NN-",
# replace hyphens with spaces, title-case the rest.
RAW="${SLUG#[0-9][0-9]-}"
TITLE="$(echo "$RAW" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2)); print}')"

log "Scaffolding: papers/$SLUG"
log "Style:       $STYLE"
log "Title:       $TITLE"

mkdir -p "$PAPER_DIR"/{sections,figures,references,frontmatter,backmatter}
mkdir -p "$ROOT/configs/papers"

# ── configs/papers/<slug>.conf ──────────────────────────────────────────
TOC="false"
[[ "$STYLE" == "academic" ]] && TOC="true"

cat > "$CONF" <<CONFEOF
# configs/papers/${SLUG}.conf — metadata for this paper
# Sourced by scripts/generate.sh and scripts/build.sh.

PAPER_TITLE="$TITLE"
PAPER_AUTHOR="Mahdi Mamashli (Genix)"
PAPER_EMAIL="bitsgenix@gmail.com"
PAPER_STYLE="$STYLE"
PAPER_YEAR="$YEAR"
PAPER_FONTSIZE="12pt"

PDF_TITLE="$TITLE"
PDF_SUBJECT=""
PDF_KEYWORDS=""

BIB_FILE="references/paper.bib"
TOC="$TOC"

ENGINE="pdflatex"
BIBTEX="biber"

# Content, in reading order. Add/reorder freely; create the matching
# file under sections/ and re-run 'make paper PAPER=$SLUG'.
SECTIONS=(
  "sections/01-introduction"
  "sections/02-background"
  "sections/03-approach"
  "sections/04-analysis"
  "sections/05-conclusion"
)

# Backmatter, in order. bibliography is required for citations to print;
# remove it only if the paper truly has none.
BACKMATTER=(
  "backmatter/bibliography"
)
CONFEOF

# ── frontmatter/abstract.tex ────────────────────────────────────────────
cat > "$PAPER_DIR/frontmatter/abstract.tex" <<'EOF'
% frontmatter/abstract.tex — written by hand for this paper.
% Included right after \maketitle by the generated main.tex.

\begin{abstract}
Write a concise abstract here. One paragraph, no citations, no jargon
that isn't defined. State the problem, the approach, and the main
finding.
\end{abstract}

\paragraph{Keywords} keyword one; keyword two; keyword three.
EOF

# ── backmatter/bibliography.tex ─────────────────────────────────────────
cat > "$PAPER_DIR/backmatter/bibliography.tex" <<'EOF'
% backmatter/bibliography.tex
% \input by main.tex (generated) as the final BACKMATTER item.
% Prints every \autocite/\cite'd source as a numbered Appendix list.

\appendix
\section*{Bibliography}
\addcontentsline{toc}{section}{Bibliography}
\printbibliography[heading=none]
EOF

# ── sections/*.tex stubs ─────────────────────────────────────────────────
cat > "$PAPER_DIR/sections/01-introduction.tex" <<'EOF'
\section{Introduction}
\label{sec:intro}

State the problem plainly. Why does it matter? End with a short outline
of the paper.
EOF

cat > "$PAPER_DIR/sections/02-background.tex" <<'EOF'
\section{Background}
\label{sec:background}

Cover the prior work and concepts the reader needs. Cite sources with
\autocite{key} — it drops a numbered footnote with the full reference
on the same page.
EOF

cat > "$PAPER_DIR/sections/03-approach.tex" <<'EOF'
\section{Approach}
\label{sec:approach}

Describe the argument or method precisely enough to reproduce.
EOF

cat > "$PAPER_DIR/sections/04-analysis.tex" <<'EOF'
\section{Analysis}
\label{sec:analysis}

Work through the evidence, proof, or results.
EOF

cat > "$PAPER_DIR/sections/05-conclusion.tex" <<'EOF'
\section{Conclusion}
\label{sec:conclusion}

One paragraph: problem, approach, finding, future work.
EOF

# ── references/paper.bib ─────────────────────────────────────────────────
cat > "$PAPER_DIR/references/paper.bib" <<'EOF'
% BibTeX references for this paper.
% Cite with \autocite{key} in the section files — numeric marker,
% footnote with full reference on the same page.

@article{example2024,
  author  = {Last, First},
  title   = {A Title That Matters},
  journal = {Journal of Important Things},
  year    = {2024},
  volume  = {1},
  number  = {1},
  pages   = {1--10},
  doi     = {10.0000/example},
}
EOF

# ── figures/README ────────────────────────────────────────────────────────
cat > "$PAPER_DIR/figures/README.md" <<'EOF'
# Figures

Place all figures for this paper here. Supported formats: PDF, PNG, EPS.

  \begin{figure}[htbp]
    \centering
    \includegraphics[width=0.9\linewidth]{figures/my-figure}
    \caption{Caption text.}
    \label{fig:my-figure}
  \end{figure}
EOF

# ── Generate the initial main.tex ────────────────────────────────────────
bash "$SCRIPT_DIR/generate.sh" "$SLUG"

# ── Update LIST_OF_PAPERS ─────────────────────────────────────────────────
LIST="$ROOT/papers/LIST_OF_PAPERS"
echo "$SLUG  [$STYLE]  $TITLE" >> "$LIST"

echo ""
success "Scaffolded: papers/$SLUG"
echo ""
echo -e "  ${CYAN}Style:${RESET}   $STYLE"
echo -e "  ${CYAN}Title:${RESET}   $TITLE"
echo ""
echo -e "  ${CYAN}Next steps:${RESET}"
echo -e "    1. Write content in papers/$SLUG/sections/*.tex"
echo -e "    2. Write the abstract in papers/$SLUG/frontmatter/abstract.tex"
echo -e "    3. Add references to papers/$SLUG/references/paper.bib"
echo -e "    4. Build: make paper PAPER=$SLUG"
echo ""