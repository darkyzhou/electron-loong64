
# Path to the local electron repository
export REPO_PATH="/home/builduser/electron-loong64"

# `.electron_build_tools` directory will by default locates at the home directory
export DEPOT_PATH="/home/builduser/.electron_build_tools/third_party/depot_tools"

# Path to the build root directory
export ROOT_PATH="/home/builduser/buildroot"

# Path to the build `src` directory
export SRC_PATH="$ROOT_PATH/src"

# Path to the build output directory
export OUT_PATH="$SRC_PATH/out/Release"

# Electron repository
export ELECTRON_REPO="https://github.com/darkyzhou/electron.git"

export ELECTRON_BRANCH="v43.4.1-loong64"

# The version to build
export ELECTRON_VERSION="43.4.1"

# Path to the release output directory
export RELEASE_PATH="$ROOT_PATH/release/$ELECTRON_VERSION"

# The rollup version to use in rollup.sh
# See third_party/devtools-frontend/src/package-lock.json
export ROLLUP_VERSION="4.50.1"

# For compiling electron
export CC=clang CXX=clang++ RUSTC_BOOTSTRAP=1

# Chromium 150's alink rule adds the archiver to ninja inputs via
# rebase_path(ar), so these must be absolute paths, not bare command names.
export AR=/usr/bin/ar NM=/usr/bin/nm

# The unbundle host toolchain (build/toolchain/linux/unbundle:host) reads these
# separately; without them gcc_toolchain("host") gets an empty `ar`.
export BUILD_CC=clang BUILD_CXX=clang++ BUILD_AR=/usr/bin/ar BUILD_NM=/usr/bin/nm