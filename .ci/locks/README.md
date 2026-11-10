# CI dependency locks

These manifests define the external toolchain used by the Papers CI build. Treat changes as reviewed dependency upgrades, not incidental workflow edits.

- `go-tools.lock` pins the `gix` and `psx` Go command versions. The Go module, compiler, and installed-binary cache key includes this file's hash and the resolved Go version.
- `python-requirements.lock` pins Python build dependencies. The pip download cache key includes this file's hash and the runner OS.
- `ubuntu-packages.lock` lists the Ubuntu packages required for LaTeX, fonts, SVG conversion, and native compilation of `m-mdy-m/log.c`. The apt archive cache key includes this file's hash, runner OS, and architecture. It caches downloaded `.deb` archives; apt still installs them on each fresh runner.

Update the relevant manifest whenever CI adds, removes, or upgrades a dependency. Keep the workflow's install commands manifest-driven so the lock files remain the single reviewed source of package versions/names. These manifests pin package names and selected tool versions; they do not snapshot the Ubuntu repository or every transitive apt package version.
