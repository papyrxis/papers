# Papers — Mahdi Mamashli (Genix)

A structured LaTeX workspace for writing, building, and releasing research papers,
standalone booklets, resumes, and learning roadmaps — all from source to PDF and
to Markdown for every major article platform.

Built on the [Papyrxis workspace](https://github.com/papyrxis/workspace) system
(same foundation as [Arliz](https://github.com/papyrxis/arliz)).

---

## Quick start

```bash
# Papers
make new-paper SLUG=02-my-paper STYLE=academic    # scaffold a new paper
make paper     PAPER=02-my-paper                   # build to PDF
make export    PAPER=02-my-paper TARGET="devto ieee" # export as article Markdown

# Booklets
make booklet SLUG=01-what-data-is-and-why-it-must-become-physical LANG=en
make booklet-export \
  SLUG=01-what-data-is-and-why-it-must-become-physical \
  LANG=en CHAPTERS=1,2 TARGET="devto ieee scirp"  # export chapters as articles

# Everything else
make list          # list all papers
make booklet-list  # list all booklets
make help          # full command reference
```

## Build reference

```bash
# ── Papers ────────────────────────────────────────────────────────────────────
make new-paper  SLUG=<slug> STYLE=<style>        # scaffold
make paper      PAPER=<slug|#>                   # build → PDF
make build                                        # build all → PDF
make export     PAPER=<slug|#|all>               # export to Markdown (all targets)
make export     PAPER=<slug|#|all> TARGET="..."  # export to specific target(s)
make watch      PAPER=<slug|#>                   # auto-rebuild on save
make list                                         # list papers

# ── Booklets ──────────────────────────────────────────────────────────────────
make new-booklet    SLUG=<slug>                  # scaffold EN + FA skeleton
make booklet        SLUG=<slug> [LANG=<en|fa>]   # build → PDF (both langs if no LANG)
make booklet-all                                  # build all booklets
make booklet-list                                 # list booklets & build status
make booklet-watch  SLUG=<slug> LANG=<en|fa>     # watch mode
make booklet-clean  [SLUG=<slug>] [LANG=<en|fa>] # clean artifacts
make booklet-export SLUG=<slug> [LANG=en] \
                    [CHAPTERS=1,2] [TARGET="..."] # export chapters as articles

# ── Resumes ───────────────────────────────────────────────────────────────────
make resume         LANG=<lang|#>               # build → PDF
make resume-all                                  # build all resumes
make resume-rename  LANG=<lang|#> NAME=<name>   # rename output PDF
make resume-list                                 # list resumes

# ── Roadmaps ──────────────────────────────────────────────────────────────────
make roadmap        ROADMAP=<slug|#>            # build → PDF
make roadmap-all                                 # build all roadmaps
make roadmap-new    SLUG=<slug>                 # scaffold
make roadmap-list                                # list roadmaps

# ── Global ────────────────────────────────────────────────────────────────────
make clean           # remove all build artifacts
make version         # show version + build date
make help            # full command reference
```

---

## Releases

Every push to `main` triggers a rolling **pre-release** (`latest-pre-release`).
Pushing a `vX.Y.Z` tag creates a **stable release**.

Both releases attach the compiled PDFs for all papers, booklets (EN + FA),
resumes, and roadmaps with direct download links.