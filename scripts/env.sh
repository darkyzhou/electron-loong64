
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

export ELECTRON_BRANCH="v39.2.3-loong64"

# The version to build
export ELECTRON_VERSION="39.2.3"

# Path to the release output directory
export RELEASE_PATH="$ROOT_PATH/release/$ELECTRON_VERSION"

# The rollup version to use in rollup.sh
# See third_party/devtools-frontend/src/package-lock.json
export ROLLUP_VERSION="4.32.0"

# For compiling electron
export CC=clang CXX=clang++ AR=ar NM=nm RUSTC_BOOTSTRAP=1