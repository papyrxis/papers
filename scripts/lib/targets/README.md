# Export System

`scripts/export.sh` converts a paper's LaTeX sources into clean Markdown,
customized per publishing platform.

## Usage

```bash
bash scripts/export.sh <slug|#|all> [target ...]
```

- `slug|#` — the paper to export (full slug, e.g. `01-the-nature-of-data`,
  or its position in `make list` / `bash scripts/list-papers.sh`).
- `all` — every paper that has a `configs/papers/*.conf`.
- `target ...` — one or more platform targets. Omit entirely (or pass
  `all-targets`) to export every target at once.

```bash
bash scripts/export.sh 01-the-nature-of-data devto medium

bash scripts/export.sh 01-the-nature-of-data

bash scripts/export.sh all
```

Output lands at `build/<slug>/<target>/<slug>.md`.

You can also drive this from the interactive menu:

```bash
bash scripts/papers.sh export
```

## Targets

Each platform is defined by a small config file in
`scripts/lib/targets/*.target.sh`:

| Target     | File                   | Citation style          | Heading        | Notes |
|------------|------------------------|--------------------------|-----------------|-------|
| `devto`    | `devto.target.sh`      | numeric `[1]` (IEEE CSL) | References      | optional Forem front matter (commented out) |
| `medium`   | `medium.target.sh`     | numeric `[1]`            | References      | no front matter (Medium doesn't read it) |
| `reddit`   | `reddit.target.sh`     | numeric `[1]`            | References      | no H1/byline — Reddit's title is a separate field |
| `ieee`     | `ieee.target.sh`       | numeric `[1]`            | References      | editable draft, not a camera-ready IEEEtran file |
| `ssrn`     | `ssrn.target.sh`       | author-date              | References      | for the abstract/landing text, not the uploaded paper |
| `scirp`    | `scirp.target.sh`      | numeric `[1]`            | References      | SCIRP journals use citation-sequence numbering |
| `journal`  | `journal.target.sh`    | author-date              | Bibliography    | generic academic/journal default |
| `personal` | `personal.target.sh`   | author-date              | References      | edit `FRONT_MATTER_TEMPLATE` for your site generator |

### Adding a new target

Copy any existing `*.target.sh` file into `scripts/lib/targets/`, rename
it, and adjust:

```bash
TARGET_LABEL="My Site"          # shown in log output
CSL_FILE="ieee.csl"             # or chicago-author-date.csl / apa.csl
REFERENCES_HEADING="References" # heading text for the bibliography
REFERENCES_NUMBERED="1"         # 1 = numbered list to match [1] citations
                                 # 0 = plain paragraphs (author-date styles)
OUTPUT_EXT="md"
FRONT_MATTER_TEMPLATE=""        # optional YAML front matter, supports
                                 # {{TITLE}}, {{DATE}}, {{AUTHOR}}, {{TAGS}}
FRONT_MATTER_COMMENTED="0"      # 1 = wrap front matter in an HTML comment
INCLUDE_H1_TITLE="1"            # 0 = skip the title heading entirely
INCLUDE_BYLINE="1"              # 0 = skip the *Author — email* line
```

It's picked up automatically — no changes needed to `export.sh` itself.

### CSL styles

Citation styles live in `scripts/lib/csl/*.csl` (standard
[Citation Style Language](https://citationstyles.org/) files, the same
format Zotero/Mendeley use). Currently bundled:

- `ieee.csl` — numeric, `[1]` in-text, used by `devto`, `medium`,
  `reddit`, `ieee`, `scirp`
- `chicago-author-date.csl` — `(Author Year)` in-text, used by `journal`,
  `ssrn`, `personal`
- `apa.csl` — included but unused by any target; assign it to a
  `CSL_FILE` value if you want APA-style citations somewhere

Drop in any other `.csl` file from the
[official style repository](https://github.com/citation-style-language/styles)
and reference it from a target's `CSL_FILE`.