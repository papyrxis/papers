VERSION    ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
BUILD_DATE ?= $(shell date -u '+%Y-%m-%d_%H:%M:%S')

WORKSPACE_ROOT := $(shell pwd)

ifeq ($(shell [ -d "workspace" ] && echo 1 || echo 0), 1)
    WORKSPACE_SRC := workspace/src
else
    WORKSPACE_SRC := $(WORKSPACE_ROOT)/src
endif

PAPER  ?=
TARGET ?=
AVAILABLE_TARGETS := $(notdir $(basename $(wildcard scripts/lib/targets/*.target.sh)))
AVAILABLE_TARGETS := $(AVAILABLE_TARGETS:.target=)

.PHONY: all build sync clean watch version new-paper generate list help \
        export targets delete-paper

all: help

generate:
ifndef PAPER
	$(error PAPER is not set. Usage: make generate PAPER=01-function-theoretic-definition-of-data)
endif
	@bash scripts/generate.sh "$(PAPER)"

paper:
ifndef PAPER
	$(error PAPER is not set. Usage: make paper PAPER=<slug|#>)
endif
	@bash scripts/build.sh "$(PAPER)"

build:
	@bash scripts/build.sh all

export:
ifndef PAPER
	$(error PAPER is not set. Usage: make export PAPER=<slug|#|all> [TARGET=<target ...>])
endif
	@bash scripts/export.sh "$(PAPER)" $(TARGET)

targets:
	@echo ""
	@echo "  Export targets (scripts/lib/targets/*.target.sh):"
	@echo "  ──────────────────────────────────────────────────────────"
	@for t in $(AVAILABLE_TARGETS); do echo "    $$t"; done
	@echo ""
	@echo "  Usage: make export PAPER=<slug|#|all> TARGET=\"<target ...>\""
	@echo ""

sync:
	@bash $(WORKSPACE_SRC)/sync.sh

watch:
ifndef PAPER
	$(error PAPER is not set. Usage: make watch PAPER=<slug|#>)
endif
	@bash scripts/build.sh "$(PAPER)" --watch

new-paper:
ifndef SLUG
	$(error SLUG is not set. Usage: make new-paper SLUG=02-my-paper-title STYLE=personal)
endif
	@bash scripts/new-paper.sh "$(SLUG)" "$(or $(STYLE),personal)"

delete-paper:
ifndef PAPER
	$(error PAPER is not set. Usage: make delete-paper PAPER=<slug|#>)
endif
	@bash scripts/delete-paper.sh "$(PAPER)"

list:
	@bash scripts/list-papers.sh

clean:
	@bash scripts/clean.sh
	@find . -type f \( \
		-name "*.aux" -o -name "*.log" -o -name "*.out" \
		-o -name "*.toc" -o -name "*.bbl" -o -name "*.blg" \
		-o -name "*.synctex.gz" -o -name "*.fdb_latexmk" \
		-o -name "*.fls" -o -name "*.idx" -o -name "*.ilg" \
		-o -name "*.ind" -o -name "*.run.xml" -o -name "*.bcf" \
		\) -delete 2>/dev/null || true
	@echo "✓ Clean"

version:
	@echo "Version:    $(VERSION)"
	@echo "Build date: $(BUILD_DATE)"

help:
	@echo ""
	@echo "  Papers — Genix"
	@echo "  ──────────────────────────────────────────────────────────"
	@echo ""
	@echo "  Most commands accept PAPER=<slug> or PAPER=<#> — the number"
	@echo "  shown by 'make list' (1, 2, 3, ...)."
	@echo ""
	@echo "  make sync                              Sync .pxis/ from workspace.yml"
	@echo "  make new-paper SLUG=<slug> STYLE=<s>  Scaffold a new paper"
	@echo "    Styles: personal | academic | ieee | two-column | single-column | journal"
	@echo ""
	@echo "  make generate PAPER=<slug|#>           Regenerate main.tex only"
	@echo "  make paper    PAPER=<slug|#>           Generate + build one paper to PDF"
	@echo "  make build                              Generate + build every paper to PDF"
	@echo "  make watch    PAPER=<slug|#>           Auto-rebuild on save"
	@echo ""
	@echo "  make export   PAPER=<slug|#|all> [TARGET=<t ...>]"
	@echo "                                           Export to Markdown, customized per platform"
	@echo "                                           (omit TARGET for every platform at once)"
	@echo "  make targets                            List available export platforms"
	@echo ""
	@echo "  make list                               List all papers (also syncs the README index)"
	@echo "  make delete-paper PAPER=<slug|#>       Delete a paper completely"
	@echo "  make clean                              Remove all build artifacts"
	@echo "  make version                            Show version info"
	@echo ""
	@echo "  Examples:"
	@echo "    make new-paper SLUG=02-type-confusion-taxonomy STYLE=academic"
	@echo "    make paper PAPER=01-function-theoretic-definition-of-data"
	@echo "    make paper PAPER=1"
	@echo "    make export PAPER=1"
	@echo "    make export PAPER=1 TARGET=devto"
	@echo "    make export PAPER=1 TARGET=\"devto medium\""
	@echo "    make export PAPER=all"
	@echo "    make targets"
	@echo "    make delete-paper PAPER=2"
	@echo ""

.DEFAULT_GOAL := help
