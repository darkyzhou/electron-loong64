#!/usr/bin/env bash

set -ex

ROOT_PATH=${ROOT_PATH:-"/home/builduser/buildroot"}

pushd "$ROOT_PATH"

git -C src clean -fd || true; git -C src am --abort || true; git -C src reset --hard HEAD;
git -C src submodule foreach 'git clean -fd || true; git am --abort || true; git reset --hard HEAD';
git -C src/electron clean -fd || true; git -C src/electron reset --hard HEAD;

popd
