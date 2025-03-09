#!/usr/bin/env bash

set -ex

ROOT_PATH=${ROOT_PATH:-"/home/builduser/buildroot"}
ROLLUP_VERSION=4.32.0

# Shamelessly copied from https://github.com/lcpu-club/loongarch-packages/blob/master/electron34/loong.patch

pushd "$ROOT_PATH"/src/third_party/node
  sed -i -e 's/@rollup/rollup/' -e "s/'wasm-node',//" node_modules.py
  jq ".dependencies.rollup=\"$ROLLUP_VERSION\"" package.json > package.json.new
  mv package.json{.new,}
  ./update_npm_deps
popd

pushd "$ROOT_PATH"/src/third_party/devtools-frontend/src
  sed -i -e 's/@rollup/rollup/' -e "s/'wasm-node',//" scripts/devtools_paths.py
  jq ".devDependencies.rollup=\"$ROLLUP_VERSION\" | .devDependencies.\"@rollup/rollup-linux-loongarch64-gnu\"=\"$ROLLUP_VERSION\"" package.json > package.json.new
  mv package.json{.new,}

  # Chromium hosts a custom registry at https://npm.skia.org/chrome-devtools/ and rejects some packages:
  # Package fs-extra with version 11.3.0 was created 108h0m0s time ago. This is less than 1 week and so failed the audit.
  sed -i /registry/d .npmrc

  # Replace direct invocation of wasm rollup
  sed -i 's\@rollup/wasm-node\rollup\' \
    inspector_overlay/BUILD.gn \
    front_end/models/live-metrics/web-vitals-injected/BUILD.gn \
    front_end/Images/BUILD.gn \
    front_end/panels/recorder/injected/BUILD.gn \
    scripts/build/ninja/bundle.gni

  python3 scripts/deps/manage_node_deps.py
popd