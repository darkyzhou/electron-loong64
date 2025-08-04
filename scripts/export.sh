#!/usr/bin/env bash

set -ex

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

pushd "$SRC_PATH"

# Add all changes to staging area
git add .

# Exclude submodules since electron build tools might ignore them
git restore --staged $(git submodule status | cut -d' ' -f2)

# Commit changes in the main repository
git commit -m "loong64 support

Co-authored-by: Jiajie Chen <c@jia.je>" || echo "No changes to commit in main repository"

# Export patches for chromium (main repository)
npx e patches chromium

# Handle submodules that have changes
echo "Checking submodules for changes..."
CHANGED_SUBMODULES=()

# Collect submodules with changes
while IFS= read -r submodule_name; do
    if [ -n "$(git -C "$submodule_name" status --porcelain)" ]; then
        echo "Changes found in submodule: $submodule_name"
        git -C "$submodule_name" add .
        git -C "$submodule_name" commit -m "loong64 support

Co-authored-by: Jiajie Chen <c@jia.je>" || echo "No changes to commit in submodule: $submodule_name"
        CHANGED_SUBMODULES+=("$submodule_name")
    fi
done < <(git submodule status | cut -d' ' -f2)

# Print the list of changed submodules
echo ""
echo "=== Summary of changed submodules ==="
if [ ${#CHANGED_SUBMODULES[@]} -eq 0 ]; then
    echo "No submodules have changes."
else
    echo "The following submodules have changes:"
    for submodule in "${CHANGED_SUBMODULES[@]}"; do
        echo "  - $submodule"
    done
fi

popd