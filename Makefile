VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
BUILD_DATE ?= $(shell date -u '+%Y-%m-%d_%H:%M:%S')
PX := python3 scripts/px.py
PAPER ?=
SLUG ?=
LANG ?=
STYLE ?= personal
TARGET ?=
CHAPTERS ?= all
AVAILABLE_TARGETS := $(patsubst scripts/lib/targets/%.target.sh,%, $(wildcard scripts/lib/targets/*.target.sh))

.PHONY: all help doctor sync version build clean paper watch export targets list styles new-paper delete-paper booklet booklet-all booklet-list booklet-watch booklet-clean booklet-delete new-booklet booklet-export

all: help

doctor:
	@$(PX) help
	@command -v pdflatex >/dev/null
	@command -v xelatex >/dev/null
	@command -v latexmk >/dev/null
	@command -v biber >/dev/null
	@command -v pandoc >/dev/null

sync:
	@git submodule update --init --recursive
	@git submodule update --remote --merge workspace

version:
	@echo "Version: $(VERSION)"
	@echo "Build date: $(BUILD_DATE)"

# Pipeline LaTeX preset delegates to this target. Build publication content only.
build:
	@PROJECT_VERSION="$(VERSION)" BUILD_DATE="$(BUILD_DATE)" $(PX) papers build all
	@PROJECT_VERSION="$(VERSION)" BUILD_DATE="$(BUILD_DATE)" $(PX) booklets build all

paper:
ifndef PAPER
	$(error PAPER is required: make paper PAPER=<slug|#>)
endif
	@$(PX) papers build "$(PAPER)"

watch:
ifndef PAPER
	$(error PAPER is required: make watch PAPER=<slug|#>)
endif
	@$(PX) papers watch "$(PAPER)"

export:
ifndef PAPER
	$(error PAPER is required: make export PAPER=<slug|#|all> [TARGET="devto medium"])
endif
	@$(PX) papers export "$(PAPER)" $(TARGET)

targets:
	@echo "Available legacy export adapters:"
	@for target in $(AVAILABLE_TARGETS); do echo "  $$target"; done
	@echo "New projects should configure targets in workspace.yml."

list:
	@$(PX) papers list

styles:
	@$(PX) papers styles

new-paper:
ifndef SLUG
	$(error SLUG is required: make new-paper SLUG=<slug> STYLE=<style>)
endif
	@$(PX) papers new "$(SLUG)" "$(STYLE)"

delete-paper:
ifndef PAPER
	$(error PAPER is required: make delete-paper PAPER=<slug|#>)
endif
	@$(PX) papers delete "$(PAPER)"

booklet:
ifndef SLUG
	$(error SLUG is required: make booklet SLUG=<slug> [LANG=en|fa])
endif
	@$(PX) booklets build "$(SLUG)"$(if $(LANG),":$(LANG)",)

booklet-all:
	@$(PX) booklets build all

booklet-list:
	@$(PX) booklets list

booklet-watch:
ifndef SLUG
	$(error SLUG is required: make booklet-watch SLUG=<slug> LANG=en|fa)
endif
ifndef LANG
	$(error LANG is required: make booklet-watch SLUG=<slug> LANG=en|fa)
endif
	@$(PX) booklets watch "$(SLUG):$(LANG)"

booklet-clean:
ifdef SLUG
	@$(PX) booklets clean "$(SLUG)"$(if $(LANG),":$(LANG)",)
else
	@$(PX) booklets clean
endif

booklet-delete:
ifndef SLUG
	$(error SLUG is required: make booklet-delete SLUG=<slug> [LANG=en|fa])
endif
	@$(PX) booklets delete "$(SLUG)"$(if $(LANG),":$(LANG)",)

new-booklet:
ifndef SLUG
	$(error SLUG is required: make new-booklet SLUG=<slug>)
endif
	@$(PX) booklets new "$(SLUG)"

booklet-export:
ifndef SLUG
	$(error SLUG is required: make booklet-export SLUG=<slug> [LANG=en] [CHAPTERS=1,2] [TARGET="devto ieee"])
endif
	@bash scripts/lib/export-chapters.sh "$(SLUG)" "$(if $(LANG),$(LANG),en)" "$(CHAPTERS)" "$(TARGET)"

clean:
	@$(PX) papers clean
	@$(PX) booklets clean
	@find papers booklets build -type f -name "*.aux" -delete 2>/dev/null || true
	@find papers booklets build -type f -name "*.log" -delete 2>/dev/null || true
	@find papers booklets build -type f -name "*.out" -delete 2>/dev/null || true
	@find papers booklets build -type f -name "*.toc" -delete 2>/dev/null || true
	@find papers booklets build -type f -name "*.bbl" -delete 2>/dev/null || true
	@find papers booklets build -type f -name "*.blg" -delete 2>/dev/null || true
	@find papers booklets build -type f -name "*.synctex.gz" -delete 2>/dev/null || true
	@find papers booklets build -type f -name "*.fdb_latexmk" -delete 2>/dev/null || true
	@find papers booklets build -type f -name "*.fls" -delete 2>/dev/null || true
	@find papers booklets build -type f -name "*.run.xml" -delete 2>/dev/null || true
	@find papers booklets build -type f -name "*.bcf" -delete 2>/dev/null || true

help:
	@echo "Papyrxis Publications"
	@echo "  make build                                Build all papers and booklets"
	@echo "  make paper PAPER=<slug|#>                Build one paper"
	@echo "  make new-paper SLUG=<slug> STYLE=academic"
	@echo "  make export PAPER=<slug|#|all> TARGET=\"devto ieee\""
	@echo "  make booklet SLUG=<slug> [LANG=en|fa]"
	@echo "  make booklet-all | booklet-list | new-booklet SLUG=<slug>"
	@echo "  make booklet-export SLUG=<slug> LANG=en CHAPTERS=1,2 TARGET=\"devto ieee\""
	@echo "  make targets | list | styles | watch PAPER=<slug>"
	@echo "  make clean | sync | doctor | version"
	@echo "  CVs await transfer; roadmaps are not part of this repository."

.DEFAULT_GOAL := help
