#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <image:tag> <path-inside-container> [local-path]"
  exit 1
}

[[ $# -lt 2 ]] && usage

IMAGE="$1"
IN_PATH="$2"
OUT_PATH="${3:-$(basename "$IN_PATH")}"   # default to file name in cwd

# make OUT_PATH absolute and ensure parent dir exists
OUT_PATH="$(realpath -m "$OUT_PATH")"
mkdir -p "$(dirname "$OUT_PATH")"

# extract
docker run --rm \
  -v "$OUT_PATH":/out \
  "$IMAGE" \
  sh -c "cp -r '$IN_PATH' /out/"

echo "Extracted to: $OUT_PATH"
