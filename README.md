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

## 📚 Papers

<!-- papers-index:begin -->
| # | Paper | Style | Download |
|---|-------|-------|----------|
| 01 | [The Nature of Data](papers/01-the-nature-of-data/) | academic | [📄 PDF](https://github.com/papyrxis/papers/releases/download/latest-pre-release/2026_Genix_The_Nature_of_Data.pdf) |
<!-- papers-index:end -->

**Export a paper as an article:**

```bash
make export PAPER=01-the-nature-of-data TARGET="devto ieee medium scirp"
# Output: build/01-the-nature-of-data/<target>/01-the-nature-of-data.md
```

---

## 📖 Booklets

Booklets are standalone volumes extracted from **Arliz** (the full book series).
Each booklet ships in both an **English** and a **Farsi/Persian** edition.

<!-- booklets-index:begin -->
| # | Booklet | EN | FA |
|---|---------|:--:|:--:|
| 01 | [What Data Is, and Why It Must Become Physical](booklets/01-what-data-is-and-why-it-must-become-physical/) | [📄 PDF](https://github.com/papyrxis/papers/releases/download/latest-pre-release/Mamashli-What-Data-Is-EN.pdf) | [📄 PDF](https://github.com/papyrxis/papers/releases/download/latest-pre-release/Mamashli-What-Data-Is-FA.pdf) |
<!-- booklets-index:end -->

### Booklet 01 — chapters

| Chapter | Title | Status |
|---------|-------|--------|
| 1 | The Nature of Data | ✅ Complete |
| 2 | The Philosophy of Representation | ✅ Complete |
| 3 | From Abstract Representation to Physical Signal | 🔧 In progress |

**Export chapters as articles** (chapters 1 and 2 are ready for publication):

```bash
# Export to a single platform
make booklet-export \
  SLUG=01-what-data-is-and-why-it-must-become-physical \
  LANG=en CHAPTERS=1,2 TARGET=devto

# Export to multiple platforms at once
make booklet-export \
  SLUG=01-what-data-is-and-why-it-must-become-physical \
  LANG=en CHAPTERS=1,2 TARGET="devto ieee medium scirp"

# Export all chapters to all platforms
make booklet-export \
  SLUG=01-what-data-is-and-why-it-must-become-physical LANG=en

# Output: build/booklets/<slug>/en/articles/<target>/chapter0N.md
```

> **Note for formal submission (SCIRP / IEEE):** Booklet chapters are written in
> a long-form book style. Before submitting to a journal, you will need to add a
> standalone abstract, keywords, and author affiliation block. The exported
> Markdown is a clean starting point — the chapter text, citations, and references
> are all correctly formatted. Use the exported file as your draft and add the
> required front matter manually.

---

## 📋 Resumes

<!-- resumes-index:begin -->
| Language | Download |
|----------|----------|
| English | [📄 PDF](https://github.com/papyrxis/papers/releases/download/latest-pre-release/Mahdi-Mamashli-Resume-en.pdf) |
| Farsi / Persian | [📄 PDF](https://github.com/papyrxis/papers/releases/download/latest-pre-release/Mahdi-Mamashli-Resume-fa.pdf) |
<!-- resumes-index:end -->

```bash
make resume LANG=en                              # build English resume
make resume-rename LANG=en NAME=Mahdi-Mamashli-Resume-2026
```

---

## 🗺️ Roadmaps

<!-- roadmaps-index:begin -->
| # | Roadmap | Download |
|---|---------|----------|
| 01 | [Master Roadmap](roadmaps/01-master-roadmap/) | [📄 PDF](https://github.com/papyrxis/papers/releases/download/latest-pre-release/01-master-roadmap.pdf) |
| 02 | [Repair Roadmap](roadmaps/02-repair-roadmap/) | [📄 PDF](https://github.com/papyrxis/papers/releases/download/latest-pre-release/02-repair-roadmap.pdf) |
| 03 | [Projects Roadmap](roadmaps/03-projects-roadmap/) | [📄 PDF](https://github.com/papyrxis/papers/releases/download/latest-pre-release/03-projects-roadmap.pdf) |
<!-- roadmaps-index:end -->

```bash
make roadmap ROADMAP=01-master-roadmap
make roadmap-all
```

---

## Article export targets

Papers and completed booklet chapters can be exported to clean Markdown
via `pandoc` with per-platform citation styles and front matter.

| Target | Platform | Citation | Notes |
|--------|----------|----------|-------|
| `devto` | [dev.to](https://dev.to) | IEEE `[1]` | Commented-out Forem YAML front matter |
| `medium` | [Medium](https://medium.com) | IEEE `[1]` | No front matter (Medium ignores it) |
| `reddit` | Reddit | IEEE `[1]` | No H1/byline — title is a separate field |
| `ieee` | IEEE (editable draft) | IEEE `[1]` | Starting point, not camera-ready IEEEtran |
| `scirp` | [SCIRP](https://www.scirp.org) | IEEE `[1]` | Citation-sequence numbering |
| `ssrn` | [SSRN](https://ssrn.com) | Chicago | For abstract/landing page text |
| `journal` | Generic journal | Chicago | Generic academic default |
| `personal` | Personal blog/site | Chicago | Customize `FRONT_MATTER_TEMPLATE` in target file |

```bash
make targets   # list all available platforms
```

CSL citation styles in `scripts/lib/csl/`: `ieee.csl`, `chicago-author-date.csl`, `apa.csl`.
Add any style from [citationstyles.org](https://citationstyles.org/) and reference it
in a new `*.target.sh` file.

---

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