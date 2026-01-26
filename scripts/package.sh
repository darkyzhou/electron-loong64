#!/usr/bin/env bash

set -ex

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

AUTO_CONTINUE=true

function main() {
    local function_name="package"

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-auto)
                AUTO_CONTINUE=false
                shift
                ;;
            *)
                function_name=$1
                shift
                ;;
        esac
    done

    if [[ "$(type -t ${function_name})" != "function" ]]; then
        echo "Error: Function '${function_name}' not found"
        exit 1
    fi

    ${function_name}
}

# https://github.com/riscv-forks/electron-riscv-releases/blob/main/.github/workflows/release.yml
function package() {
    pushd "$ROOT_PATH"/src
    
    echo ">>> Package Debug Symbols <<<"

    rm -rf "$OUT_PATH"/breakpad_symbols
    ninja -C "$OUT_PATH" electron:electron_symbols || echo "Failed to run electron:electron_symbols"

    echo ">>> Package Electron <<<"

    rm -rf "$RELEASE_PATH"
    mkdir -p "$RELEASE_PATH"

    ninja -C "$OUT_PATH" electron:electron_dist_zip
    mv "$OUT_PATH"/dist.zip "$RELEASE_PATH"/electron-v$ELECTRON_VERSION-linux-loong64.zip

    ninja -C "$OUT_PATH" electron:licenses
    ninja -C "$OUT_PATH" electron:electron_version_file
    DELETE_DSYMS_AFTER_ZIP=1 electron/script/zip-symbols.py -b "$OUT_PATH"

    [ -f "$OUT_PATH"/debug.zip ] && mv "$OUT_PATH"/debug.zip "$RELEASE_PATH"/electron-v$ELECTRON_VERSION-linux-loong64-debug.zip
    [ -f "$OUT_PATH"/symbols.zip ] && mv "$OUT_PATH"/symbols.zip "$RELEASE_PATH"/electron-v$ELECTRON_VERSION-linux-loong64-symbols.zip

    popd

    if [[ "$AUTO_CONTINUE" == "true" ]]; then
        build_mksnapshot
    fi
}

function build_mksnapshot() {
    pushd "$ROOT_PATH"/src
    echo ">>> Build Mksnapshot <<<"

    ninja -C "$OUT_PATH" electron:electron_mksnapshot
    gn desc "$OUT_PATH" v8:run_mksnapshot_default args > "$OUT_PATH"/mksnapshot_args

    # Remove unused args from mksnapshot_args
    sed -i '/.*builtins-pgo/d' "$OUT_PATH"/mksnapshot_args
    sed -i '/--turbo-profiling-input/d' "$OUT_PATH"/mksnapshot_args
    sed -i '/The gn arg use_goma=true .*/d' "$OUT_PATH"/mksnapshot_args

    ninja -C "$OUT_PATH" electron:electron_mksnapshot_zip
    cd "$OUT_PATH"
    zip mksnapshot.zip mksnapshot_args gen/v8/embedded.S
    mv "$OUT_PATH"/mksnapshot.zip "$RELEASE_PATH"/mksnapshot-v$ELECTRON_VERSION-linux-loong64.zip

    popd

    if [[ "$AUTO_CONTINUE" == "true" ]]; then
        chromedriver
    fi
}

function chromedriver() {
    pushd "$ROOT_PATH"/src

    echo ">>> Build Chromedriver <<<"
    ninja -C "$OUT_PATH" electron:electron_chromedriver_zip
    mv "$OUT_PATH"/chromedriver.zip "$RELEASE_PATH"/chromedriver-v$ELECTRON_VERSION-linux-loong64.zip

    popd

    if [[ "$AUTO_CONTINUE" == "true" ]]; then
        nodejs
    fi
}

function nodejs() {
    pushd "$ROOT_PATH"/src

    echo ">>> Build Node.js headers <<<"

    ELECTRON_OUT_DIR=Release ninja -C "$OUT_PATH" electron:node_headers
    mv "$OUT_PATH"/gen/node_headers.tar.gz "$RELEASE_PATH"/node-v$ELECTRON_VERSION-headers.tar.gz

    popd

    if [[ "$AUTO_CONTINUE" == "true" ]]; then
        ffmpeg
    fi
}

function ffmpeg() {
    pushd "$ROOT_PATH"/src

    echo ">>> Build ffmpeg <<<"
    ninja -C "$OUT_PATH"/ffmpeg electron:electron_ffmpeg_zip
    mv "$OUT_PATH"/ffmpeg/ffmpeg.zip "$RELEASE_PATH"/ffmpeg-v$ELECTRON_VERSION-linux-loong64.zip
    
    popd

    if [[ "$AUTO_CONTINUE" == "true" ]]; then
        hunspell
    fi
}

function hunspell() {
    pushd "$ROOT_PATH"/src

    echo ">>> Build hunspell <<<"
    ninja -C "$OUT_PATH" electron:hunspell_dictionaries_zip
    mv "$OUT_PATH"/hunspell_dictionaries.zip "$RELEASE_PATH"/hunspell-dictionaries.zip
    
    popd

    if [[ "$AUTO_CONTINUE" == "true" ]]; then
        libcxx
    fi
}

function libcxx() {
    pushd "$ROOT_PATH"/src
    
    echo ">>> Build libcxx <<<"
    ninja -C "$OUT_PATH" electron:libcxx_headers_zip
    ninja -C "$OUT_PATH" electron:libcxxabi_headers_zip
    ninja -C "$OUT_PATH" electron:libcxx_objects_zip
    mv "$OUT_PATH"/libcxx_headers.zip "$RELEASE_PATH"/libcxx-headers.zip
    mv "$OUT_PATH"/libcxxabi_headers.zip "$RELEASE_PATH"/libcxxabi-headers.zip
    mv "$OUT_PATH"/libcxx_objects.zip "$RELEASE_PATH"/libcxx-objects-v$ELECTRON_VERSION-linux-loong64.zip

    popd

    if [[ "$AUTO_CONTINUE" == "true" ]]; then
        shasum256
    fi
}

function shasum256() {
    pushd "$RELEASE_PATH"

    rm -f SHASUMS256.txt
    for file in *; do
        checksum=$(sha256sum "$file" | cut -d ' ' -f 1)
        echo "$checksum *$file" >> SHASUMS256.txt
    done

    popd
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
