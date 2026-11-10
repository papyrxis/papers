# Papyrxis Publications

Books, booklets and standalone articles published by Papyrxis.

This repository owns publication content: document sources, references, figures and project-specific editorial metadata. Reusable tooling belongs in Papyrxis Workspace: https://github.com/papyrxis/workspace.

The intended repository name is papyrxis/publications. This PR does not change GitHub repository metadata; the current URL remains papyrxis/papers until the owner renames it.

## Scope

Included: research papers, standalone articles, books and educational booklets, including English and Persian editions.

Excluded from publication authoring and the local CLI: personal CVs/resumes and personal roadmaps. Roadmap content is removed from this repository. Resume source files remain temporarily in the legacy tree for transfer to a dedicated repository under m-mdy-m. Per the owner's explicit request, CI builds both resume languages as a separate artifact and attaches them only to the rolling latest-pre-release; versioned stable releases remain publication-only.

## Authoring instructions

Use the directory-specific agent instructions before drafting or revising content:

| Content | Instructions | Scope |
| --- | --- | --- |
| Research papers and standalone articles | [papers/AGENTS.md](papers/AGENTS.md) | Research integrity, argument structure, citations, figures, and article builds |
| Books and booklets | [booklets/AGENTS.md](booklets/AGENTS.md) | Learning design, chapter structure, bilingual editions, references, and PDF quality |
| Personal resume sources | [resumes/AGENTS.md](resumes/AGENTS.md) | Person-first positioning, one-page layout, evidence, privacy, and the legacy build boundary |

The resume guide applies only when the owner explicitly requests work on the retained personal sources. It does not change the repository's publication scope or add resumes to the normal publication build and release pipeline.

## Structure

    papers/                 standalone papers and articles
    booklets/               books and booklets, language editions
    configs/papers/         legacy paper metadata
    configs/booklets/       booklet metadata
    scripts/papers.py       publication-specific compatibility commands
    scripts/booklets.py     booklet-specific compatibility commands
    scripts/lib/            publication export adapters and filters
    workspace/              shared Workspace Git submodule
    build/                  generated artifacts; do not edit

Shared Python, LaTeX, logging, process, configuration and release helpers belong in Workspace. Do not copy them into this repository.

## Requirements

- Python 3.10+.
- TeX Live with pdfLaTeX, XeLaTeX, latexmk, Biber and the packages used by each document.
- Pandoc for Markdown export.
- gix for version/branch workflows and psx for repository quality policy.
- m-mdy-m/log.c for native structured logs.
- m-mdy-m/pipeline for CI/CD. GitHub Actions consumes the shared LaTeX toolchain action from the Pipeline main branch.

## Quick start

    git clone --recurse-submodules https://github.com/papyrxis/papers.git
    cd papers
    git submodule update --init --recursive
    make list
    make build

Create and build a publication:

    make new-paper SLUG=02-my-article STYLE=academic
    make new-booklet SLUG=02-my-booklet
    make paper PAPER=01-my-paper
    make booklet SLUG=01-my-booklet LANG=fa

## Export targets and CSL

Target differences should be configuration, not repeated build scripts. A target should define only genuine differences: output format, front matter, title/byline policy, bibliography heading, optional Lua filters and optional CSL.

- No global CSL is assumed.
- A target without explicit CSL uses Pandoc's default citation style when cite processing is enabled.
- dev.to and Medium do not attach the IEEE CSL file.
- Targets that need a particular citation style declare only that style.
- Identical CSL files must not be copied into individual publications.

## CI and releases

The reusable build workflow runs the Pipeline LaTeX preset, builds papers and booklets, validates generated PDFs, and uploads one publication artifact. Releases contain publication PDFs only.

## Migration notes

See docs/REPOSITORY-BOUNDARIES.md. Resume files are intentionally retained until the destination repository under m-mdy-m can be created and the transfer verified. No CV data is deleted by this refactor.

Each published work should carry its own copyright and third-party-material notices. See CONTENT-LICENSE.md.
