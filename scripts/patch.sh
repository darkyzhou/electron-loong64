#!/usr/bin/env bash

set -ex

ROOT_PATH=${ROOT_PATH:-"/home/builduser/buildroot"}
REPO_PATH=${REPO_PATH:-"/home/builduser/electron-loong64"}
DEPOT_PATH=${DEPOT_PATH:-"/home/builduser/.electron_build_tools/third_party/depot_tools"}

pushd "$ROOT_PATH"

git -C src/electron clean -fd
git -C src/electron reset --hard HEAD
git -C src/electron apply --reject "$REPO_PATH"/patches/chromium.patch
git -C src/electron apply --reject "$REPO_PATH"/patches/electron.patch

# Workaround for a strange Python error: "Cannot call rmtree on a symbolic link"
git -C "$DEPOT_PATH" reset --hard HEAD
git -C "$DEPOT_PATH" apply --reject "$REPO_PATH"/patches/depot.patch

popd
