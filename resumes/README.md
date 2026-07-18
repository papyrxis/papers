# resumes/

Modular resume source files, one directory per language.

```
resumes/
├── en/
│   └── resume.tex       ← English resume (xelatex, Charter)
└── fa/
    └── resume.tex       ← Persian resume (xelatex, Vazirmatn, RTL)
```

## Adding a new language variant

1. Create `resumes/<lang>/resume.tex`
2. Create `configs/resumes/<lang>.conf` — copy an existing one and adjust
3. Run `bash scripts/resume.sh build <lang>`

## Sections (optional modularization)

For larger resumes you can split into sections and `\input{}` them:

```
resumes/en/
├── resume.tex           ← main file, \input{}s sections
└── sections/
    ├── header.tex
    ├── experience.tex
    ├── projects.tex
    └── education.tex
```

The build script compiles from the `resumes/<lang>/` directory,
so all relative paths in `\input{}` commands resolve correctly.
