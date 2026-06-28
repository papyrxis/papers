# Papers — Mahdi Mamashli (Genix)

A structured LaTeX repository for writing, building, and releasing research papers — from formal academic submissions to personal technical essays.

Built on the [Papyrxis workspace](https://github.com/papyrxis/workspace) system (same foundation as [Arliz](https://github.com/papyrxis/arliz)).

## Quick start

```bash
make new-paper SLUG=02-my-paper-title STYLE=academic   # scaffold a paper
make paper     PAPER=02-my-paper-title                  # build it to PDF
make export    PAPER=02-my-paper-title                  # export it to Markdown
                                                          # (dev.to, Medium, Reddit, IEEE, ...)
make list                                                # see every paper
make help                                                # full command reference
```

Full documentation for every script, the `Makefile`, and the
multi-platform Markdown exporter lives in
[`docs/SCRIPTS.md`](docs/SCRIPTS.md).

<!-- papers-index:begin -->
## Papers Index

| # | Slug | Style | Title |
|---|------|-------|-------|
| 01 | `01-the-nature-of-data` | academic | [The Nature of Data](https://github.com/papyrxis/papers/releases/download/latest-pre-release/2026_Genix_The_Nature_of_Data.pdf) |
<!-- papers-index:end -->
