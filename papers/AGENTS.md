# Agent Instructions — Papers and Articles

These instructions apply to every document under this directory. They govern research papers, technical papers, essays, and standalone articles. They do not replace the shared publishing toolchain or a publication's own explicit editorial brief.

## Mission and editorial standard

Write work that is accurate, understandable, traceable, and worth reading. A paper is an argument supported by evidence, not a collection of confident-sounding paragraphs. An article should answer a clear question for a defined reader.

Before drafting, state internally:
- the central question or claim;
- the intended reader and the knowledge they are expected to have;
- the contribution and what is deliberately out of scope;
- the evidence needed to support each important claim;
- the publication language, audience, and target format.

Prefer a narrow, defensible contribution over a broad, weakly supported one.

## Repository boundaries

- This directory owns article and paper content: prose, equations, figures, source references, and publication-specific metadata.
- Reusable LaTeX components, Python tooling, export targets, build orchestration, logging, and release automation belong in Papyrxis Workspace.
- Read the repository README and docs/REPOSITORY-BOUNDARIES.md before changing repository structure.
- Do not copy shared Workspace code into a publication.
- Do not change the pinned Workspace package version, shared schemas, CI workflows, or repository-wide build behavior as an incidental part of editing prose.
- Never edit generated files under build/. Change their source and rebuild instead.

## Inspect before editing

1. Read the root README, this directory's README, the relevant publication's main.tex and metadata, and its current section files.
2. Read workspace.yml and the applicable Workspace template or preset. Respect existing configuration rather than inventing a parallel build path.
3. Inspect references, figures, licenses, and the current output target before changing them.
4. Preserve existing author work and local changes. Do not replace a whole file when a focused edit is sufficient.
5. If the brief conflicts with a repository boundary or a documented publication decision, explain the conflict and choose the smallest safe change.

## Publication structure

Create new papers through the repository scaffold, for example:

    make new-paper SLUG=02-clear-topic STYLE=academic

Use the scaffold as the authoritative structure. The typical layout separates:
- the entry point and publication metadata;
- abstract and other front matter;
- numbered sections;
- bibliography and reference data;
- figures, tables, and appendices where needed.

Keep filenames stable, descriptive, and ordered. Do not place several unrelated articles in one publication directory. A standalone article uses sections rather than book chapters.

## Argument and evidence

- Define the research question, problem, or thesis precisely.
- Distinguish definitions, assumptions, observations, derived results, interpretations, and opinions.
- Support substantive factual claims with traceable sources or reproducible analysis.
- Prefer primary sources, standards, specifications, peer-reviewed work, and original datasets where appropriate.
- Verify every citation's author, title, venue, year, DOI or URL, and the claim it is used to support.
- Never fabricate references, quotations, page numbers, results, datasets, experiments, benchmarks, or statistical significance.
- Do not imply that a proposed design has been implemented, tested, or evaluated unless the source evidence proves it.
- Report limitations, uncertainty, negative results, and competing explanations honestly.
- Keep quotations short and clearly attributed. Paraphrase in original language and cite the source.
- Do not use a bibliography entry as a substitute for a citation next to the claim it supports.

## Suggested paper structure

Use only the sections the argument actually needs. A research paper may include:
1. Title, author information, abstract, and keywords.
2. Introduction: question, motivation, scope, and contribution.
3. Background and related work.
4. Definitions, assumptions, or theoretical framework.
5. Method, design, or analysis.
6. Results or the main argument.
7. Discussion, limitations, and implications.
8. Conclusion and references.

A technical article may be shorter and more practical. It should still explain its assumptions, distinguish facts from recommendations, and provide enough context for the reader to follow the reasoning.

## Technical accuracy

- Explain unfamiliar terminology before relying on it.
- Keep notation consistent and define symbols close to first use.
- Check equations dimensionally and logically; verify derivations independently.
- Make code examples coherent, minimal, and runnable where they are presented as runnable.
- State language, runtime, tool, platform, and version assumptions.
- Never present pseudocode as production code or a hypothetical result as measured evidence.
- Ensure diagrams, tables, and examples support the surrounding argument rather than decorate it.

## References, figures, and licensing

- Store references in the publication's bibliography source; do not duplicate a global bibliography without a reason.
- Use the citation style required by the publication or export target. CSL is target-specific; do not assume a global CSL.
- Give figures and tables descriptive captions and refer to them in the text.
- Record the origin and license of externally sourced images, fonts, datasets, code, and diagrams.
- Do not reproduce third-party material beyond its license or applicable quotation rights.
- Keep publication-specific copyright and content-license statements with the publication.

## English and Persian editions

When a publication has both English and Persian editions:
- maintain separate entry points and language-specific metadata;
- preserve equivalent technical meaning, not merely word-for-word phrasing;
- use correct right-to-left typesetting and isolate Latin code, identifiers, URLs, and equations appropriately;
- keep terminology consistent with the project's glossary;
- do not claim that a Persian edition is complete while its substantive chapters remain placeholders;
- identify untranslated, abridged, or provisional material explicitly.

Follow the engine and language configuration in workspace.yml. Do not assume that every project uses the same TeX engine.

## Build and quality checks

Use the repository's supported commands:
- make list to inspect available papers;
- make paper PAPER=<slug> to build one paper;
- make export PAPER=<slug> TARGET="..." for explicitly configured targets;
- make build for the complete publication set;
- make doctor to inspect the local toolchain and repository checks.

After a build:
- inspect the PDF, not just the exit code;
- check references, links, equations, figures, tables, page breaks, and bibliography;
- verify that the title and metadata match the actual content;
- verify every enabled export target independently;
- ensure generated output is not accidentally committed.

Do not report a successful build unless the command actually ran and the resulting artifact was inspected. CI for this repository does not validate the legacy resume sources.

## Completion criteria

A paper or article is ready when its question and contribution are clear, its claims are supported, its references are verified, its limitations are explicit, its typesetting is sound, its license and metadata are correct, and its configured build/export checks pass.
