#!/usr/bin/env bash

set -ex

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

install_executable() {
  local src="$1"
  local dst="$2"
  local dir tmp

  dir="$(dirname "$dst")"
  tmp="$(mktemp "$dir/.tmp.XXXXXX")"
  cp "$src" "$tmp"
  chmod 755 "$tmp"
  mv -f "$tmp" "$dst"
}

pushd "$ROOT_PATH"/src
  install_executable /usr/bin/node third_party/node/linux/node-linux-x64/bin/node
  install_executable /usr/lib/node_modules/@esbuild/linux-loong64/bin/esbuild third_party/devtools-frontend/src/third_party/esbuild/esbuild

popd