#!/usr/bin/env bash

set -ex

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

rm -f "$OUT_PATH"/electron
pushd "$SRC_PATH"
  gn gen "$OUT_PATH" --args="import(\"//electron/build/args/release.gn\")" --script-executable=/usr/bin/python3
  ninja -C "$OUT_PATH" electron
popd