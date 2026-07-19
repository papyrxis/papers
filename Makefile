VERSION    ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
BUILD_DATE ?= $(shell date -u '+%Y-%m-%d_%H:%M:%S')

WORKSPACE_ROOT := $(shell pwd)

ifeq ($(shell [ -d "workspace" ] && echo 1 || echo 0), 1)
    WORKSPACE_SRC := workspace/src
else
    WORKSPACE_SRC := $(WORKSPACE_ROOT)/src
endif

PAPER    ?=
TARGET   ?=
ROADMAP  ?=
LANG     ?=
NAME     ?=
SLUG     ?=
STYLE    ?= personal

AVAILABLE_TARGETS := $(patsubst scripts/lib/targets/%.target.sh,%,\
                       $(wildcard scripts/lib/targets/*.target.sh))

PX := python scripts/px.py

.PHONY: all help version sync \
        paper build watch generate export targets list new-paper delete-paper \
        roadmap roadmap-all roadmap-watch roadmap-list roadmap-new roadmap-clean roadmap-delete \
        resume resume-all resume-watch resume-clean resume-rename resume-list \
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
	@echo "  Usage: make export PAPER=<slug|#|all> TARGET=\"<tgt ...>\""
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
	@echo "Version:    $(VERSION)"
	@echo "Build date: $(BUILD_DATE)"

# ── help ──────────────────────────────────────────────────────────────────────

help:
	@echo ""
	@echo "  Papers — Genix"
	@echo "  ──────────────────────────────────────────────────────────"
	@echo ""
	@echo "  Interactive:"
	@echo "    python scripts/px.py                      Full interactive UI"
	@echo "    python scripts/papers.py                  Papers UI"
	@echo "    python scripts/resumes.py                 Resumes UI"
	@echo "    python scripts/roadmaps.py                Roadmaps UI"
	@echo ""
	@echo "  Papers:"
	@echo "    make sync                                 Sync .pxis/ from workspace.yml"
	@echo "    make new-paper  SLUG=<slug> STYLE=<s>     Scaffold a new paper"
	@echo "      Styles: personal | academic | ieee | two-column | single-column | journal"
	@echo "    make paper      PAPER=<slug|#>            Build one paper to PDF"
	@echo "    make build                                Build every paper to PDF"
	@echo "    make watch      PAPER=<slug|#>            Auto-rebuild on save"
	@echo "    make export     PAPER=<slug|#|all>        Export to Markdown (all targets)"
	@echo "    make export     PAPER=<slug|#|all> TARGET=\"<t ...>\""
	@echo "                                              Export to specific target(s)"
	@echo "    make targets                              List available export platforms"
	@echo "    make list                                 List all papers"
	@echo "    make styles                               Show available paper styles"
	@echo "    make delete-paper PAPER=<slug|#>          Delete a paper completely"
	@echo ""
	@echo "  Roadmaps:"
	@echo "    make roadmap        ROADMAP=<slug|#>      Build one roadmap"
	@echo "    make roadmap-all                          Build all roadmaps"
	@echo "    make roadmap-watch  ROADMAP=<slug|#>      Watch mode"
	@echo "    make roadmap-new    SLUG=<slug>           Scaffold a new roadmap"
	@echo "    make roadmap-list                         List roadmaps"
	@echo "    make roadmap-clean  [ROADMAP=<slug|#>]    Clean roadmap artifacts"
	@echo "    make roadmap-delete ROADMAP=<slug|#>      Delete a roadmap"
	@echo ""
	@echo "  Resumes:"
	@echo "    make resume        LANG=<lang|#>          Build one resume"
	@echo "    make resume-all                           Build all resumes"
	@echo "    make resume-watch  LANG=<lang|#>          Watch mode"
	@echo "    make resume-clean  [LANG=<lang|#>]        Clean resume artifacts"
	@echo "    make resume-rename LANG=<lang|#> NAME=<n> Rename output PDF"
	@echo "    make resume-list                          List resumes"
	@echo ""
	@echo "  Global:"
	@echo "    make clean                                Remove all build artifacts"
	@echo "    make version                              Show version info"
	@echo ""
	@echo "  Examples:"
	@echo "    make new-paper SLUG=02-type-theory STYLE=academic"
	@echo "    make paper PAPER=1"
	@echo "    make export PAPER=1 TARGET=\"devto medium\""
	@echo "    make roadmap ROADMAP=01-master-roadmap"
	@echo "    make resume LANG=en"
	@echo "    make resume-rename LANG=en NAME=Mahdi-Mamashli-Resume-2026"
	@echo ""

.DEFAULT_GOAL := help