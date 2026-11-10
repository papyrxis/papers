# Agent Instructions — Personal Resume and CV

These instructions govern the personal resume sources retained in this repository. The resume is about the author, not a showcase page for one project. The goal is a credible, readable, one-page professional profile.

## Primary rule: the person comes first

Position the author through a consistent professional identity, working style, capabilities, and body of work. Projects are evidence for that identity; they are not the identity itself.

A good resume should answer:
- what kind of problems the author works on;
- what the author can design, build, maintain, and explain;
- which technical areas are supported by real work;
- how the author's projects and writing connect into a coherent professional profile.

Use a broad headline that can survive a change in the author's current flagship project. Avoid making the title or summary a list of repository names.

## Accuracy and evidence

Never invent or inflate:
- employers, job titles, client work, contracts, or employment dates;
- degree status, institution, graduation date, awards, or certifications;
- years of experience, project counts, article/book counts, package downloads, stars, or user numbers;
- test coverage, performance improvements, reliability, security reviews, or production adoption;
- language proficiency, seniority, or expertise based only on a dependency appearing in a repository.

Treat existing resume text as a draft, not independent proof. Recheck time-sensitive metrics against their source before using them. Prefer durable descriptions of responsibility and technical scope over numbers that will quickly become stale.

The current source uses the name Mahdi Mamashli / مهدی ممشلی, while public developer profiles use the handle Genix. Do not silently replace the author's name with a handle or infer a legal name from a username. Ask the owner to resolve identity conflicts before a public release that changes the displayed name. Existing location entries conflict; omit location unless the owner confirms one.

## Contact and privacy

Use only contact channels the owner has deliberately published for professional contact. The current profile provides an email address, GitHub, personal website, Dev.to, Medium, npm, Stack Overflow, and ORCID links.

Do not add a street address, date of birth, identity number, private phone number, family information, or other unnecessary personal details. Never expose secrets, tokens, private repository names, or private customer information.

## One-page requirement

Maintain one A4 page per language edition:
- English and Persian are separate one-page documents.
- Keep the same factual claims, project selection, dates, and education status in both editions.
- Use a concise summary, a small set of evidence-based skill groups, independent-development experience, no more than four selected workstreams, education, and a short writing/publishing statement.
- Remove repeated claims between the summary, experience, projects, and writing sections.
- Prefer fewer strong points to tiny fonts or crowded columns.
- Keep links clickable and PDF metadata accurate.
- Maintain readable contrast and a logical reading order; do not rely on color alone.

The English and Persian documents may differ in line breaks and phrasing, but not in meaning or factual claims.

## Professional narrative

Describe the author's practice rather than making the resume a project catalog. Suitable themes, when supported by current work, include:
- systems and application engineering;
- backend architecture and APIs;
- developer tools and engineering infrastructure;
- modular software, explicit contracts, and extensible systems;
- open-source maintenance and cross-platform development;
- technical writing and bilingual educational publishing.

Choose only the themes evidenced by the current portfolio. Do not claim a specialization that the code and documentation do not support.

## Skills

- List technologies used meaningfully in authored or maintained work.
- Group skills by purpose: languages, backend, systems, architecture, and development tooling.
- Do not add a framework merely because it appears in a lockfile or a dependency tree.
- Avoid skill bars, proficiency percentages, and unqualified words such as expert.
- Prefer concrete capabilities such as protocol design, extension architecture, test automation, or reproducible builds when the work demonstrates them.

## Selected work

- Select a maximum of four workstreams that collectively represent the author's breadth.
- Balance systems/editor work, backend/framework work, developer infrastructure/packages, and technical publishing where those areas remain current.
- Describe the author's contribution and the engineering problem, not just the project's feature list.
- Link to the canonical repository or package profile. Do not use outdated personal-fork URLs when a project has moved to an organization.
- Distinguish stable functionality from experimental or incomplete work. For example, label an experimental desktop renderer as experimental.
- Do not present a planned feature, issue, draft ADR, open PR, or prerelease candidate as a finished capability.

## Current source facts to treat carefully

The existing files state a Computer Engineering bachelor's program at Islamic Azad University with dates 2023–Present. Preserve this only as an existing owner-provided entry; do not change it to a completed degree or add a graduation date without confirmation.

The repository's current resume content includes claims about 3+ years, 20+ repositories, 15+ articles, four books, 80%+ test coverage, and download counts. These figures are not automatically validated by their presence in the old resume. Omit them unless each is freshly verified and deliberately retained.

## Repository and build boundaries

The root README and docs/REPOSITORY-BOUNDARIES.md define resumes as personal material retained temporarily for migration to a dedicated repository. The root Makefile and standard CI/release workflows deliberately exclude resume sources.

- Keep resume files in this transitional directory only while the owner requests work here.
- Do not reintroduce resume commands into the publication CLI or include a personal CV in publication releases as an incidental change.
- Do not claim the normal papers CI compiled, paginated, or visually inspected the resume; it does not.
- If the resume is moved later, preserve source history and verify the destination build before deleting the retained copy.
- Do not commit generated PDFs or TeX build artifacts unless the owner explicitly requests them.

## Review checklist

Before completion, verify that:
1. the summary is person-first and not project-first;
2. all claims are supported and dates are consistent;
3. English and Persian versions have factual parity;
4. no location or personal detail was guessed;
5. project links use canonical current URLs;
6. the document is intended to fit one A4 page;
7. the PDF metadata matches the visible author and title;
8. build and visual verification are reported honestly.
