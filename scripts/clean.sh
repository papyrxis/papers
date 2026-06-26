#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Cleaning paper build artifacts"

for conf in "$ROOT"/configs/papers/*.conf; do
  [[ -f "$conf" ]] || continue
  slug="$(basename "$conf" .conf)"
  gen="$ROOT/papers/$slug/main.tex"
  if [[ -f "$gen" ]] && head -5 "$gen" | grep -q "inherited template"; then
    rm -v "$gen"
  fi
done

[[ -d "$ROOT/build" ]] && rm -rf "$ROOT/build" && echo "removed build/"

echo "==> Clean complete"