#!/usr/bin/env bash

set -ex

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

pushd "$ROOT_PATH"
  git -C "$DEPOT_PATH" fetch origin main
  git -C "$DEPOT_PATH" reset --hard origin/main
  export VPYTHON_BYPASS="manually managed python not supported by chrome operations"
  export SENTRYCLI_SKIP_DOWNLOAD=1
  npx e sync --three-way -f
popd
