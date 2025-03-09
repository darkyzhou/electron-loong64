#!/usr/bin/env bash

set -ex

ROOT_PATH=${ROOT_PATH:-"/home/builduser/buildroot"}
ELECTRON_REPO=${ELECTRON_REPO:-"https://github.com/electron/electron.git"}
ELECTRON_VERSION=${ELECTRON_VERSION:-"34.2.0"}
DEPOT_PATH=${DEPOT_PATH:-"/home/builduser/.electron_build_tools/third_party/depot_tools"}

pushd "$ROOT_PATH"

git -C src clean -fd || true; git -C src am --abort || true; git -C src reset --hard HEAD;
git -C src submodule foreach 'git clean -fd || true; git am --abort || true; git reset --hard HEAD';

git -C src/electron clean -fd || true; git -C src/electron reset --hard HEAD;
git -C src/electron remote set-url origin "$ELECTRON_REPO"
git -C src/electron fetch origin --tags
git -C src/electron switch --detach "v$ELECTRON_VERSION"

popd
