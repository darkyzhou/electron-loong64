#!/usr/bin/env bash

set -ex

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

function main() {
    local function_name=${1:-package}

    if [[ "$(type -t ${function_name})" != "function" ]]; then
        echo "Error: Function '${function_name}' not found"
        exit 1
    fi

    ${function_name}
}

function package() {
    pushd "$ROOT_PATH"/src
    echo ">>> Package Debug Symbols and Strip Binaries <<<"

    rm -rf "$OUT_PATH"/breakpad_symbols

    electron/script/copy-debug-symbols.py -d "$OUT_PATH" --out-dir="$OUT_PATH"/debug --compress
    electron/script/strip-binaries.py -d "$OUT_PATH" --verbose
    electron/script/add-debug-link.py -d "$OUT_PATH" --debug-dir="$OUT_PATH"/debug

    ninja -C "$OUT_PATH" electron:licenses
    ninja -C "$OUT_PATH" electron:electron_version_file
    DELETE_DSYMS_AFTER_ZIP=1 electron/script/zip-symbols.py -b "$OUT_PATH"

    rm -rf "$RELEASE_PATH"
    mkdir -p "$RELEASE_PATH"
    mv "$OUT_PATH"/debug.zip "$RELEASE_PATH"/electron-v$ELECTRON_VERSION-linux-loong64-debug.zip
    mv "$OUT_PATH"/symbols.zip "$RELEASE_PATH"/electron-v$ELECTRON_VERSION-linux-loong64-symbols.zip

    echo ">>> Package Electron <<<"

    ninja -C "$OUT_PATH" electron:electron_dist_zip
    mv "$OUT_PATH"/dist.zip "$RELEASE_PATH"/electron-v$ELECTRON_VERSION-linux-loong64.zip

    popd

    build_mksnapshot
}

function build_mksnapshot() {
    pushd "$ROOT_PATH"/src
    echo ">>> Build Mksnapshot <<<"

    ninja -C "$OUT_PATH" electron:electron_mksnapshot
    gn desc "$OUT_PATH" v8:run_mksnapshot_default args > "$OUT_PATH"/mksnapshot_args

    # Remove unused args from mksnapshot_args
    sed -i '/.*builtins-pgo/d' "$OUT_PATH"/mksnapshot_args
    sed -i '/--turbo-profiling-input/d' "$OUT_PATH"/mksnapshot_args
    electron/script/strip-binaries.py --file "$OUT_PATH"/mksnapshot --verbose
    electron/script/strip-binaries.py --file "$OUT_PATH"/v8_context_snapshot_generator --verbose

    ninja -C "$OUT_PATH" electron:electron_mksnapshot_zip
    cd "$OUT_PATH"
    zip mksnapshot.zip mksnapshot_args gen/v8/embedded.S
    mv "$OUT_PATH"/mksnapshot.zip "$RELEASE_PATH"/mksnapshot-v$ELECTRON_VERSION-linux-loong64.zip

    popd

    chromedriver
}

function chromedriver() {
    pushd "$ROOT_PATH"/src
    echo ">>> Build Chromedriver <<<"
    EU_STRIP_PATH="$ROOT_PATH"/src/buildtools/third_party/eu-strip/bin/eu-strip
    rm -rf "$EU_STRIP_PATH"
    ln -sv `which eu-strip` "$EU_STRIP_PATH"

    ninja -C "$OUT_PATH" electron:electron_chromedriver
    ninja -C "$OUT_PATH" electron:electron_chromedriver_zip
    mv "$OUT_PATH"/chromedriver.zip "$RELEASE_PATH"/chromedriver-v$ELECTRON_VERSION-linux-loong64.zip

    popd
    nodejs
}

function nodejs() {
    pushd "$ROOT_PATH"/src

    echo ">>> Build Node.js headers <<<"
    ninja -C "$OUT_PATH" electron:node_headers
    mv "$OUT_PATH"/gen/node_headers.tar.gz "$RELEASE_PATH"/node-v$ELECTRON_VERSION-headers.tar.gz

    popd
    ffmpeg
}

function ffmpeg() {
    pushd "$ROOT_PATH"/src
    # FIXME:
    # ninja: error: '../../../../../../../usr/lib/clang/20/lib/linux/libclang_rt.builtins-loongarch64.a', needed by 'obj/third_party/opus/libopus.a', missing and no known rule to make it
    # echo ">>> Build ffmpeg <<<"

    # export CC=clang CXX=clang++ AR=ar NM=nm RUSTC_BOOTSTRAP=1
    # gn gen "$OUT_PATH"/ffmpeg --args="import(\"//electron/build/args/ffmpeg.gn\")" --script-executable=/usr/bin/python3
    # ninja -C "$OUT_PATH"/ffmpeg electron:electron_ffmpeg_zip
    # mv "$OUT_PATH"/ffmpeg/ffmpeg.zip "$RELEASE_PATH"/ffmpeg-v$ELECTRON_VERSION-linux-loong64.zip
    popd
    hunspell
}

function hunspell() {
    pushd "$ROOT_PATH"/src

    echo ">>> Build hunspell <<<"
    ninja -C "$OUT_PATH" electron:hunspell_dictionaries_zip
    mv "$OUT_PATH"/hunspell_dictionaries.zip "$RELEASE_PATH"/hunspell-dictionaries.zip
    
    popd
    libcxx
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
    shasum256
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
