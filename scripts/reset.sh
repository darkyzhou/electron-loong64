#!/usr/bin/env bash

set -ex

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

pushd "$ROOT_PATH"

git -C src clean -fd || true; git -C src am --abort || true; git -C src reset --hard HEAD;

pushd src
while IFS= read -r submodule_path; do
    [ -z "$submodule_path" ] && continue
    if [ -d "$submodule_path" ] && ([ -d "$submodule_path/.git" ] || [ -f "$submodule_path/.git" ]); then
        echo "Resetting submodule: $submodule_path"
        git -C "$submodule_path" clean -fd 2>/dev/null || true
        git -C "$submodule_path" am --abort 2>/dev/null || true
        git -C "$submodule_path" reset --hard HEAD 2>/dev/null || true
    fi
done < <(git config --file .gitmodules --get-regexp 'submodule\..*\.path' 2>/dev/null | awk '{print $2}')
popd

git -C src/electron clean -fd || true; git -C src/electron reset --hard HEAD;

popd
