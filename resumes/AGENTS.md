# Agent Instructions — Personal Resume and CV

These instructions govern the personal resume sources retained in this repository. The resume is about the author, not a showcase page for one project. Keep it credible, readable and limited to one A4 page per language.

## Primary rule: the person comes first

Position the author through a consistent professional identity, working style, capabilities and body of work. Projects are evidence for that identity, not the identity itself.

A good resume should answer:
- what kinds of problems the author works on;
- what the author can design, build, maintain and explain;
- which technical areas are supported by real work;
- how the projects and technical writing connect into a coherent profile.

Use a broad headline that can survive a change in the author's current flagship project. Avoid turning the summary into a list of repository names.

## Persian writing and technical language

The Persian edition must read like natural, contemporary Persian written for a technical audience. It is not a sentence-by-sentence translation of the English edition.

- Write the explanation in natural Persian sentence order. Do not mirror English grammar or word order.
- Keep English for proper names, programming languages, tools, protocols, APIs, and technical terms that are genuinely clearer in English (for example, \`Backend\`, \`Runtime\`, \`API\`, \`plugin\`, and \`CI/CD\`). Do not force these terms into every paragraph.
- Prefer familiar Persian words for ordinary actions: «ساخت»، «آزمون»، «انتشار»، «شاخه»، «فایل راهنما» and «پوشه».
- Do not mix English words with Persian suffixes when it makes the sentence hard to read (for example, «taskها»، «providerهای مختلف»، «branch و versioning»). Rewrite the idea as a natural Persian phrase instead.
- Avoid stacking several English technical nouns in one sentence. Explain what a tool or component actually does in words a general technical reader can understand.
- Use \`\\lr{...}\` for Latin terms where right-to-left shaping needs it; do not wrap an entire Persian sentence.
- Persian and English may use different sentence structure and line breaks, but must preserve the same factual claims.

## Accuracy and attribution

Never invent or inflate:
- employers, job titles, client work, contracts or employment dates;
- degree status, institution, graduation date, awards or certifications;
- years of experience, project counts, article/book counts, package downloads, stars or user numbers;
- test coverage, performance improvements, reliability, security reviews or production adoption;
- language proficiency, seniority or expertise based only on a dependency appearing in a repository.

Treat existing resume text as a draft, not independent proof. Prefer durable descriptions of responsibility and technical scope over numbers that quickly become stale.

Use attribution verbs precisely:
- Say the author **created** or **designed** a project when they are its creator.
- Say the author **maintains** a project only when they actually maintain it.
- Say the author **contributed to** another project only when there is attributable original work.
- Never present a fork with no original changes by the author as the author's project or contribution.

The current source uses the name Mahdi Mamashli / مهدی ممشلی, while public developer profiles use the handle Genix. Do not silently replace the author's name with a handle or infer a legal name from a username. Existing location entries conflict; omit location unless the owner confirms one.

## Contact and privacy

Use only contact channels the owner has deliberately published for professional contact. Do not add a street address, date of birth, identity number, private phone number, family information or other unnecessary personal details. Never expose secrets, tokens, private repository names or private customer information. Do not name or describe a private project in the public resume unless the owner explicitly approves that disclosure.

## One-page requirement

Maintain one A4 page per language edition:
- English and Persian are separate one-page documents.
- Keep factual claims, project maturity, dates and education status consistent.
- Use a concise summary, evidence-based skills, independent-development experience, selected projects, education and a short writing/publishing statement.
- Select up to five primary public projects with verifiable work by the author. A compact one- or two-line “Additional work” note may identify other meaningful public projects without turning the page into a repository dump.
- Remove repeated claims between the summary, experience, projects and writing sections.
- Prefer readable type and useful content to artificial whitespace or tiny fonts.
- Keep links clickable and PDF metadata accurate.
- Maintain readable contrast and a logical reading order; do not rely on color alone.

## Professional narrative

Describe the author's practice rather than making the resume a project catalog. Suitable themes, when supported by current work, include:
- systems and application engineering;
- backend architecture and APIs;
- developer tools and engineering infrastructure;
- modular software, explicit contracts and extensible systems;
- open-source maintenance and cross-platform development;
- technical writing and bilingual educational publishing.

Choose only themes evidenced by current, attributable work. Clearly distinguish implemented tools, active development, experimental components and specification-only projects. For example, CDIN's GUI-SDL renderer is experimental; Viraz is specification-first and must not be described as an implemented assistant.

## Skills

- List technologies used meaningfully in authored or maintained work.
- Group skills by purpose: languages, backend, systems, architecture and development tooling.
- Do not add a framework merely because it appears in a lockfile or dependency tree.
- Avoid skill bars, proficiency percentages and unqualified words such as “expert”.
- Prefer concrete capabilities such as protocol design, extension architecture, test automation and reproducible builds when the work demonstrates them.

## Selected work

- Choose up to five public projects that collectively represent the author's breadth.
- Describe the problem, the author's actual role and what the software does—not just its technology stack.
- Link to canonical current repositories. Do not use outdated personal-fork URLs when a project has moved to an organization.
- Distinguish stable functionality from experimental or incomplete work.
- Do not present a planned feature, issue, draft ADR, open PR or prerelease candidate as a finished capability.
- Exclude private projects and forks without original authored changes unless the owner explicitly instructs otherwise.

## Current source facts to treat carefully

The current source states a Computer Engineering bachelor's program at Islamic Azad University with dates 2023–Present. Preserve this as an existing owner-provided entry; do not change it to a completed degree or add a graduation date without confirmation.

The old resume contains unverified figures such as 3+ years, repository/article/book counts and test-coverage percentages. Omit them unless freshly verified and deliberately retained.

## Repository and build boundaries

Resume sources remain temporarily in this repository pending migration to a dedicated repository under m-mdy-m. Resume commands stay out of the local publication CLI and Makefile. By the owner's explicit request, CI builds the two language editions as a separate artifact and attaches them only to the rolling \`latest-pre-release\`; versioned stable releases remain publication-only.

- Do not commit generated PDFs or TeX build artifacts.
- Do not claim visual verification unless the rendered PDFs have actually been inspected.
- After migration is verified, preserve source history and remove the retained copies in a follow-up change.

## Review checklist

Before completion, verify that:
1. the summary is person-first and not project-first;
2. all claims are supported, attributable and clear about project maturity;
3. Persian reads naturally and uses English technical terms selectively;
4. the two editions have factual parity;
5. no private project, fork without original work, location or personal detail was included without approval;
6. both documents are one A4 page without crowding;
7. links and PDF metadata are correct;
8. build and visual verification are reported honestly.
