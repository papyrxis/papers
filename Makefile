VERSION    ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
BUILD_DATE ?= $(shell date -u '+%Y-%m-%d_%H:%M:%S')

WORKSPACE_ROOT := $(shell pwd)

ifeq ($(shell [ -d "workspace" ] && echo 1 || echo 0), 1)
    WORKSPACE_SRC := workspace/src
else
    WORKSPACE_SRC := $(WORKSPACE_ROOT)/src
endif

PAPER ?=

.PHONY: all build sync clean watch version new-paper generate list help

all: help

generate:
ifndef PAPER
	$(error PAPER is not set. Usage: make generate PAPER=01-function-theoretic-definition-of-data)
endif
	@bash scripts/generate.sh "$(PAPER)"

paper:
ifndef PAPER
	$(error PAPER is not set. Usage: make paper PAPER=01-function-theoretic-definition-of-data)
endif
	@bash scripts/build.sh "$(PAPER)"

build:
	@bash scripts/build.sh all

sync:
	@bash $(WORKSPACE_SRC)/sync.sh

watch:
ifndef PAPER
	$(error PAPER is not set. Usage: make watch PAPER=01-function-theoretic-definition-of-data)
endif
	@bash scripts/build.sh "$(PAPER)" --watch

new-paper:
ifndef SLUG
	$(error SLUG is not set. Usage: make new-paper SLUG=02-my-paper-title STYLE=personal)
endif
	@bash scripts/new-paper.sh "$(SLUG)" "$(or $(STYLE),personal)"

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
	@echo "  make sync                              Sync .pxis/ from workspace.yml"
	@echo "  make new-paper SLUG=<slug> STYLE=<s>  Scaffold a new paper"
	@echo "    Styles: personal | academic | ieee | two-column | single-column"
	@echo ""
	@echo "  make generate PAPER=<slug>             Regenerate main.tex only"
	@echo "  make paper    PAPER=<slug>             Generate + build one paper"
	@echo "  make build                              Generate + build every paper"
	@echo "  make watch    PAPER=<slug>             Auto-rebuild on save"
	@echo ""
	@echo "  make list                               List all papers"
	@echo "  make clean                              Remove all build artifacts"
	@echo "  make version                            Show version info"
	@echo ""
	@echo "  Examples:"
	@echo "    make new-paper SLUG=02-type-confusion-taxonomy STYLE=academic"
	@echo "    make paper PAPER=01-function-theoretic-definition-of-data"
	@echo ""

.DEFAULT_GOAL := help