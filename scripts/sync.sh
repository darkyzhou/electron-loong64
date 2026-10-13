#!/usr/bin/env bash

set -ex

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

# Keep the build-tools source and compiled dispatcher on the pinned revision.
# An existing checkout may already have auto-updated before the pin was set.
BUILD_TOOLS_PATH="$(dirname "$(dirname "$DEPOT_PATH")")"
if [ "$(git -C "$BUILD_TOOLS_PATH" rev-parse HEAD)" != "$BUILD_TOOLS_SHA" ]; then
  git -C "$BUILD_TOOLS_PATH" fetch origin "$BUILD_TOOLS_SHA"
  git -C "$BUILD_TOOLS_PATH" checkout --detach "$BUILD_TOOLS_SHA"
  pushd "$BUILD_TOOLS_PATH"
    node .yarn/releases/yarn-4.10.3.cjs install --immutable
    node .yarn/releases/yarn-4.10.3.cjs build
  popd
fi

pushd "$ROOT_PATH"
  git -C "$DEPOT_PATH" fetch origin main
  git -C "$DEPOT_PATH" reset --hard origin/main

  # LoongArch64 host: depot_tools/CIPD does not know this host arch.
  # Fetch x86_64 (linux-amd64) tools instead; they run through the binfmt
  # interpreter (LATX). The reset above wipes the local detect_host_arch.py
  # patch, so it must be re-applied here.
  echo linux-amd64 > "$DEPOT_PATH/.cipd_client_platform"
  touch "$DEPOT_PATH/.disable_auto_update"
  sed -i 's/host_arch = "loong64"/host_arch = "x64"/' "$DEPOT_PATH/detect_host_arch.py"
  grep -q 'host_arch = "x64"' "$DEPOT_PATH/detect_host_arch.py"

  export VPYTHON_BYPASS="manually managed python not supported by chrome operations"
  export SENTRYCLI_SKIP_DOWNLOAD=1
  npx e sync --three-way -f
popd
