#!/usr/bin/env bash

set -ex

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

pushd "$ROOT_PATH"

if [ ! -d "src/electron" ]; then
   npx e init -i release -r "$ROOT_PATH" electron-loong64
   git clone "$ELECTRON_REPO" src/electron
fi

git -C src clean -fd || true; git -C src am --abort || true; git -C src reset --hard HEAD;
git -C src submodule foreach 'git clean -fd || true; git am --abort || true; git reset --hard HEAD';

git -C src/electron clean -fd || true; git -C src/electron reset --hard HEAD;
git -C src/electron remote set-url origin "$ELECTRON_REPO"
git -C src/electron fetch origin --tags
git -C src/electron switch --detach "v$ELECTRON_VERSION"

popd
