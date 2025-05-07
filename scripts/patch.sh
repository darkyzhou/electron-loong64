#!/usr/bin/env bash

set -ex

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

pushd "$ROOT_PATH/src/electron"

git reset --hard HEAD && git clean -fd && git checkout v$ELECTRON_VERSION
git apply --reject "$REPO_PATH"/patches/chromium.patch
git add .
git commit -m "chromium.patch" --no-verify
git apply --reject "$REPO_PATH"/patches/electron.patch
git add .
git commit -m "electron.patch" --no-verify

popd

