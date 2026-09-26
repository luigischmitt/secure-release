#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/dist"

mkdir -p "$OUTPUT_DIR"
cp "$ROOT_DIR/src/index.html" "$OUTPUT_DIR/index.html"
tar -czf "$ROOT_DIR/site.tar.gz" -C "$OUTPUT_DIR" index.html

printf 'Built %s\n' "$ROOT_DIR/site.tar.gz"
