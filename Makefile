VERSION    ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
BUILD_DATE ?= $(shell date -u '+%Y-%m-%d_%H:%M:%S')

WORKSPACE_ROOT := $(shell pwd)

ifeq ($(shell [ -d "workspace" ] && echo 1 || echo 0), 1)
    WORKSPACE_SRC := workspace/src
else
    WORKSPACE_SRC := $(WORKSPACE_ROOT)/src
endif

# ── Variables ─────────────────────────────────────────────────────────────────
PAPER    ?=
TARGET   ?=
ROADMAP  ?=
LANG     ?=
NAME     ?=
SLUG     ?=
STYLE    ?= personal
CHAPTERS ?= all

AVAILABLE_TARGETS := $(patsubst scripts/lib/targets/%.target.sh,%,\
                       $(wildcard scripts/lib/targets/*.target.sh))

PX := python3 scripts/px.py

.PHONY: all help version sync \
        paper build watch generate export targets list new-paper delete-paper styles \
        roadmap roadmap-all roadmap-watch roadmap-list roadmap-new roadmap-clean roadmap-delete \
        resume resume-all resume-watch resume-clean resume-rename resume-list \
        booklet booklet-all booklet-list booklet-watch booklet-clean booklet-delete new-booklet \
        booklet-export \
        clean

# ── default ───────────────────────────────────────────────────────────────────
all: help

# ── sync ──────────────────────────────────────────────────────────────────────
sync:
	@bash $(WORKSPACE_SRC)/sync.sh

# ── papers ────────────────────────────────────────────────────────────────────
generate:
ifndef PAPER
	$(error PAPER is not set. Usage: make generate PAPER=<slug|#>)
endif
	@$(PX) papers build $(PAPER)

paper:
ifndef PAPER
	$(error PAPER is not set. Usage: make paper PAPER=<slug|#>)
endif
	@$(PX) papers build $(PAPER)

build:
	@$(PX) papers build all

export:
ifndef PAPER
	$(error PAPER is not set. Usage: make export PAPER=<slug|#|all> [TARGET="<tgt ...>"])
endif
	@$(PX) papers export $(PAPER) $(TARGET)

targets:
	@echo ""
	@echo "  Export targets (scripts/lib/targets/*.target.sh):"
	@echo "  ──────────────────────────────────────────────────────────"
	@for t in $(AVAILABLE_TARGETS); do echo "    $$t"; done
	@echo ""
	@echo "  Usage (papers):   make export PAPER=<slug|#|all> TARGET=\"<tgt ...>\""
	@echo "  Usage (booklets): make booklet-export SLUG=<slug> LANG=en CHAPTERS=1,2 TARGET=\"<tgt ...>\""
	@echo ""

watch:
ifndef PAPER
	$(error PAPER is not set. Usage: make watch PAPER=<slug|#>)
endif
	@$(PX) papers watch $(PAPER)

new-paper:
ifndef SLUG
	$(error SLUG is not set. Usage: make new-paper SLUG=<slug> STYLE=<style>)
endif
	@$(PX) papers new $(SLUG) $(STYLE)

delete-paper:
ifndef PAPER
	$(error PAPER is not set. Usage: make delete-paper PAPER=<slug|#>)
endif
	@$(PX) papers delete $(PAPER)

list:
	@$(PX) papers list

styles:
	@$(PX) papers styles

# ── roadmaps ──────────────────────────────────────────────────────────────────
roadmap:
ifndef ROADMAP
	$(error ROADMAP is not set. Usage: make roadmap ROADMAP=<slug|#>)
endif
	@$(PX) roadmaps build $(ROADMAP)

roadmap-all:
	@$(PX) roadmaps build all

roadmap-watch:
ifndef ROADMAP
	$(error ROADMAP is not set. Usage: make roadmap-watch ROADMAP=<slug|#>)
endif
	@$(PX) roadmaps watch $(ROADMAP)

roadmap-list:
	@$(PX) roadmaps list

roadmap-new:
ifndef SLUG
	$(error SLUG is not set. Usage: make roadmap-new SLUG=<slug>)
endif
	@$(PX) roadmaps new $(SLUG)

roadmap-clean:
ifdef ROADMAP
	@$(PX) roadmaps clean $(ROADMAP)
else
	@$(PX) roadmaps clean
endif

roadmap-delete:
ifndef ROADMAP
	$(error ROADMAP is not set. Usage: make roadmap-delete ROADMAP=<slug|#>)
endif
	@$(PX) roadmaps delete $(ROADMAP)

# ── resumes ───────────────────────────────────────────────────────────────────
resume:
ifndef LANG
	$(error LANG is not set. Usage: make resume LANG=<lang|#>)
endif
	@$(PX) resumes build $(LANG)

resume-all:
	@$(PX) resumes build all

resume-watch:
ifndef LANG
	$(error LANG is not set. Usage: make resume-watch LANG=<lang|#>)
endif
	@$(PX) resumes watch $(LANG)

resume-clean:
ifdef LANG
	@$(PX) resumes clean $(LANG)
else
	@$(PX) resumes clean
endif

resume-rename:
ifndef LANG
	$(error LANG is not set. Usage: make resume-rename LANG=<lang|#> NAME=<new-name>)
endif
ifndef NAME
	$(error NAME is not set. Usage: make resume-rename LANG=<lang|#> NAME=<new-name>)
endif
	@$(PX) resumes rename $(LANG) $(NAME)

resume-list:
	@$(PX) resumes list

# ── booklets ──────────────────────────────────────────────────────────────────

booklet:
ifndef SLUG
	$(error SLUG is not set. Usage: make booklet SLUG=<slug> [LANG=<en|fa>])
endif
	@$(PX) booklets build $(if $(LANG),$(SLUG):$(LANG),$(SLUG))

booklet-all:
	@$(PX) booklets build all

booklet-list:
	@$(PX) booklets list

booklet-watch:
ifndef SLUG
	$(error SLUG is not set. Usage: make booklet-watch SLUG=<slug> LANG=<en|fa>)
endif
ifndef LANG
	$(error LANG is not set. Usage: make booklet-watch SLUG=<slug> LANG=<en|fa>)
endif
	@$(PX) booklets watch $(SLUG):$(LANG)

booklet-clean:
ifdef SLUG
	@$(PX) booklets clean $(if $(LANG),$(SLUG):$(LANG),$(SLUG))
else
	@$(PX) booklets clean
endif

booklet-delete:
ifndef SLUG
	$(error SLUG is not set. Usage: make booklet-delete SLUG=<slug> [LANG=<en|fa>])
endif
	@$(PX) booklets delete $(if $(LANG),$(SLUG):$(LANG),$(SLUG))

new-booklet:
ifndef SLUG
	$(error SLUG is not set. Usage: make new-booklet SLUG=<slug>)
endif
	@$(PX) booklets new $(SLUG)

# Export booklet chapter(s) to Markdown for article platforms.
#
# Arguments:
#   SLUG     — booklet slug (required)
#   LANG     — language: en | fa  (default: en)
#   CHAPTERS — comma-separated chapter numbers, or "all"  (default: all)
#   TARGET   — space-separated platform names, or unset for all
#
# Examples:
#   make booklet-export SLUG=01-what-data-is-and-why-it-must-become-physical
#   make booklet-export SLUG=01-what-data-is-and-why-it-must-become-physical LANG=en CHAPTERS=1,2
#   make booklet-export SLUG=01-what-data-is-and-why-it-must-become-physical LANG=en CHAPTERS=1,2 TARGET="devto ieee scirp"
#
# Output: build/booklets/<slug>/<lang>/articles/<target>/chapter0N.md
booklet-export:
ifndef SLUG
	$(error SLUG is not set. Usage: make booklet-export SLUG=<slug> [LANG=en] [CHAPTERS=1,2] [TARGET="devto ieee"])
endif
	@bash scripts/lib/export-chapters.sh \
		"$(SLUG)" \
		"$(if $(LANG),$(LANG),en)" \
		"$(CHAPTERS)" \
		"$(TARGET)"

# ── clean (global) ────────────────────────────────────────────────────────────
clean:
	@$(PX) papers clean
	@$(PX) roadmaps clean
	@$(PX) resumes clean
	@find . -type f \( \
		-name "*.aux" -o -name "*.log" -o -name "*.out" \
		-o -name "*.toc" -o -name "*.bbl" -o -name "*.blg" \
		-o -name "*.synctex.gz" -o -name "*.fdb_latexmk" \
		-o -name "*.fls" -o -name "*.idx" -o -name "*.ilg" \
		-o -name "*.ind" -o -name "*.run.xml" -o -name "*.bcf" \
		\) -delete 2>/dev/null || true

# ── version ───────────────────────────────────────────────────────────────────
version:
	@echo ""
	@echo "  Version   : $(VERSION)"
	@echo "  Build date: $(BUILD_DATE)"
	@echo ""

# ── help ──────────────────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "  Papers — Genix"
	@echo "  ──────────────────────────────────────────────────────────"
	@echo ""
	@echo "  Interactive UI:"
	@echo "    python scripts/px.py                       Full TUI (all modules)"
	@echo "    python scripts/papers.py                   Papers UI"
	@echo "    python scripts/booklets.py                 Booklets UI"
	@echo "    python scripts/resumes.py                  Resumes UI"
	@echo "    python scripts/roadmaps.py                 Roadmaps UI"
	@echo ""
	@echo "  Papers:"
	@echo "    make new-paper  SLUG=<slug> STYLE=<s>      Scaffold a new paper"
	@echo "      Styles: personal | academic | ieee | two-column | single-column | journal"
	@echo "    make paper      PAPER=<slug|#>             Build one paper → PDF"
	@echo "    make build                                 Build all papers → PDF"
	@echo "    make watch      PAPER=<slug|#>             Auto-rebuild on save"
	@echo "    make export     PAPER=<slug|#|all>         Export to Markdown (all targets)"
	@echo "    make export     PAPER=<slug|#|all> TARGET=\"<t ...>\""
	@echo "                                               Export to specific platform(s)"
	@echo "    make targets                               List available export platforms"
	@echo "    make list                                  List all papers"
	@echo "    make styles                                Show available paper styles"
	@echo "    make delete-paper PAPER=<slug|#>           Delete a paper completely"
	@echo ""
	@echo "  Booklets:"
	@echo "    make new-booklet   SLUG=<slug>             Scaffold a new booklet (en + fa)"
	@echo "    make booklet       SLUG=<slug> [LANG=<l>]  Build one booklet (both langs if no LANG)"
	@echo "    make booklet-all                           Build all booklets (all languages)"
	@echo "    make booklet-list                          List booklets & build status"
	@echo "    make booklet-watch SLUG=<slug> LANG=<l>    Watch mode (one edition)"
	@echo "    make booklet-clean [SLUG=<slug>] [LANG=<l>] Clean build artifacts"
	@echo "    make booklet-delete SLUG=<slug> [LANG=<l>] Delete a booklet"
	@echo "    make booklet-export SLUG=<slug> [LANG=en] [CHAPTERS=1,2] [TARGET=\"devto ieee\"]"
	@echo "                                               Export chapter(s) as article Markdown"
	@echo ""
	@echo "  Roadmaps:"
	@echo "    make roadmap        ROADMAP=<slug|#>       Build one roadmap → PDF"
	@echo "    make roadmap-all                           Build all roadmaps"
	@echo "    make roadmap-watch  ROADMAP=<slug|#>       Watch mode"
	@echo "    make roadmap-new    SLUG=<slug>            Scaffold a new roadmap"
	@echo "    make roadmap-list                          List roadmaps"
	@echo "    make roadmap-clean  [ROADMAP=<slug|#>]     Clean roadmap artifacts"
	@echo "    make roadmap-delete ROADMAP=<slug|#>       Delete a roadmap"
	@echo ""
	@echo "  Resumes:"
	@echo "    make resume        LANG=<lang|#>           Build one resume → PDF"
	@echo "    make resume-all                            Build all resumes"
	@echo "    make resume-watch  LANG=<lang|#>           Watch mode"
	@echo "    make resume-clean  [LANG=<lang|#>]         Clean resume artifacts"
	@echo "    make resume-rename LANG=<lang|#> NAME=<n>  Rename output PDF"
	@echo "    make resume-list                           List resumes"
	@echo ""
	@echo "  Global:"
	@echo "    make sync                                  Sync workspace submodule"
	@echo "    make clean                                 Remove all build artifacts"
	@echo "    make version                               Show version + build date"
	@echo ""
	@echo "  Examples:"
	@echo "    make new-paper SLUG=02-type-theory STYLE=academic"
	@echo "    make paper     PAPER=1"
	@echo "    make export    PAPER=1 TARGET=\"devto medium ieee\""
	@echo ""
	@echo "    make booklet SLUG=01-what-data-is-and-why-it-must-become-physical LANG=en"
	@echo "    make booklet-export \\"
	@echo "      SLUG=01-what-data-is-and-why-it-must-become-physical \\"
	@echo "      LANG=en CHAPTERS=1,2 TARGET=\"devto ieee scirp\""
	@echo ""
	@echo "    make roadmap ROADMAP=01-master-roadmap"
	@echo "    make resume  LANG=en"
	@echo "    make resume-rename LANG=en NAME=Mahdi-Mamashli-Resume-2026"
	@echo ""

.DEFAULT_GOAL := help