# Repository boundaries and migration

## Workspace

Papyrxis Workspace is the reusable toolchain: YAML loading, templates, LaTeX builds, logging, process handling, target profiles, tags, changelogs and shared CI tasks. Publication-specific sources must not carry duplicate copies of these helpers.

## Publications

This repository is limited to works intended for publication: research papers, standalone articles, books and booklets. Each work owns its LaTeX source, references, figures and editorial metadata. Generic code belongs in Workspace.

## CV and resume migration

The existing resume sources are being prepared for a dedicated repository under the m-mdy-m account. The connected GitHub actions can read/write existing repositories and create branches/PRs, but cannot create a new repository or transfer repository ownership. Therefore:

1. Resume commands have been removed from the publication CLI, Makefile and release workflows.
2. Resume source directories are retained temporarily so no personal document is lost.
3. Create the destination repository under m-mdy-m, then transfer resumes/, configs/resumes/, resume templates and resume-specific metadata.
4. After verifying the destination repository and CI, remove the retained source directories here in a follow-up PR.

## Roadmaps

Roadmaps were personal planning documents, not publication content. Their content and build support are removed from this repository. No roadmap artifact is built or released.

## Repository name

The intended name is publications, with URL https://github.com/papyrxis/publications. Renaming is an owner-level repository metadata operation and is not available through the connected GitHub actions. After merging this PR, rename it in GitHub Settings > General; GitHub redirects the old URL.
