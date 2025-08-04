#!/usr/bin/env bash

set -ex

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

SKIP_GEN=false
for arg in "$@"; do
  case $arg in
    --build)
      SKIP_GEN=true
      shift
      ;;
    *)
      ;;
  esac
done

rm -f "$OUT_PATH"/electron
pushd "$SRC_PATH"
  if [ "$SKIP_GEN" = false ]; then
    gn gen "$OUT_PATH" \
      --args="import(\"//electron/build/args/release.gn\")" \
      --script-executable=/usr/bin/python3 \
      --no-check
  fi
  ninja -C "$OUT_PATH" electron
popd