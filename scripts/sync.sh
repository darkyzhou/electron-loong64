#!/usr/bin/env bash

set -ex

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

pushd "$ROOT_PATH"

git -C "$DEPOT_PATH" reset --hard HEAD

if ! npx e sync --three-way -f; then
    # Workaround for a strange Python error: "Cannot call rmtree on a symbolic link"
    git -C "$DEPOT_PATH" apply "$REPO_PATH/patches/depot.patch"
    npx e sync --three-way -f
fi

popd
