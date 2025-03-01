#!/usr/bin/env bash

set -ex

ROOT_PATH=${ROOT_PATH:-"/home/builduser/buildroot"}

pushd "$ROOT_PATH"/src
  cp /usr/local/bin/node third_party/node/linux/node-linux-x64/bin/node
  
  chmod +w third_party/devtools-frontend/src/third_party/esbuild/esbuild
  cp /usr/local/lib/node_modules/@esbuild/linux-loong64/bin/esbuild third_party/devtools-frontend/src/third_party/esbuild/esbuild
popd