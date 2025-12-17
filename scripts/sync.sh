#!/usr/bin/env bash

set -ex

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

pushd "$ROOT_PATH"
  git -C "$DEPOT_PATH" reset --hard HEAD
  npx e sync --three-way -f
popd
