#!/usr/bin/env bash

set -ex

ROOT_PATH=${ROOT_PATH:-"/home/builduser/buildroot"}
REPO_PATH=${REPO_PATH:-"/home/builduser/electron-loong64"}
DEPOT_PATH=${DEPOT_PATH:-"/home/builduser/.electron_build_tools/third_party/depot_tools"}

pushd "$ROOT_PATH"

git -C "$DEPOT_PATH" reset --hard HEAD

if ! npx e sync --three-way -f; then
    git -C "$DEPOT_PATH" apply "$REPO_PATH/depot.patch"
    npx e sync --three-way -f
fi

popd
