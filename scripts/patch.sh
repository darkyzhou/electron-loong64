#!/usr/bin/env bash

set -ex

ROOT_PATH=${ROOT_PATH:-"/home/builduser/buildroot"}
REPO_PATH=${REPO_PATH:-"/home/builduser/electron-loong64"}
DEPOT_PATH=${DEPOT_PATH:-"/home/builduser/.electron_build_tools/third_party/depot_tools"}

pushd "$ROOT_PATH/src/electron"

git clean -fd && git reset --hard HEAD
git apply --reject "$REPO_PATH"/patches/chromium.patch
git add .
git commit -m "chromium.patch" --no-verify
git apply --reject "$REPO_PATH"/patches/electron.patch
git add .
git commit -m "electron.patch" --no-verify

popd

