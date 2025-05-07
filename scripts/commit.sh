#!/usr/bin/env bash

set -ex

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

pushd "$ROOT_PATH/src"

git add .
git restore --staged $(git submodule status | cut -d' ' -f2)
git commit -m "loong64 support for chromium

Co-authored-by: Jiajie Chen <c@jia.je>"
npx e patches chromium

UPDATED_MODULES=$(git submodule foreach --quiet 'if [ -n "$(git status --porcelain)" ]; then echo "$path"; fi')

for module in $UPDATED_MODULES; do
  pushd "$module"
  
  name=$(echo "$module" | sed -n 's/.*third_party\/\([^/]*\).*/\1/p')
  echo "$module -> $name"
  
  git add .
  git commit -m "loong64 support for $name

Co-authored-by: Jiajie Chen <c@jia.je>"

  npx e patches "$name"
  
  read -n 1 -s -r -p "Press any key to continue..."

  popd
done

popd
