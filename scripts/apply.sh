#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

# Parse arguments
COMMIT_CHROMIUM=false
PATCH_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --commit-chromium)
            COMMIT_CHROMIUM=true
            shift
            ;;
        *)
            PATCH_FILE="$1"
            shift
            ;;
    esac
done

# Check if patch file is provided
if [ -z "$PATCH_FILE" ]; then
    echo "Usage: $0 [--commit-chromium] <patch-file>"
    echo "Example: $0 /path/to/chromium.patch"
    echo "Example: $0 --commit-chromium /path/to/chromium.patch"
    echo ""
    echo "Options:"
    echo "  --commit-chromium  Skip patch application and submodule operations,"
    echo "                     only add files to main repository and commit"
    exit 1
fi

# Check if patch file exists
if [ ! -f "$PATCH_FILE" ]; then
    echo "Error: Patch file not found: $PATCH_FILE"
    exit 1
fi

# Get absolute path of patch file
PATCH_FILE=$(realpath "$PATCH_FILE")
PATCH_NAME=$(basename "$PATCH_FILE")

# State file for tracking progress
STATE_DIR="$SRC_PATH/.apply-state"
STATE_FILE="$STATE_DIR/${PATCH_NAME}.state"
FILE_LIST="$STATE_DIR/${PATCH_NAME}.files"

# Create state directory if it doesn't exist
mkdir -p "$STATE_DIR"

pushd "$SRC_PATH"

echo "=== Applying patch: $PATCH_NAME ==="
echo ""

# Step 1: Parse patch file and extract modified files
if [ ! -f "$FILE_LIST" ]; then
    echo "Step 1: Parsing patch file to extract modified files..."

    # Extract file paths from patch (looking for +++ b/path/to/file lines)
    # Excluding /dev/null which indicates file deletion
    # Handle both standard format and format with timestamps
    grep '^+++' "$PATCH_FILE" | \
        grep -v '/dev/null' | \
        sed 's|^+++ b/||' | \
        awk '{print $1}' > "$FILE_LIST.tmp"

    # Also extract deleted files (--- a/path/to/file with +++ /dev/null)
    grep -B1 '^+++ /dev/null' "$PATCH_FILE" | \
        grep '^---' | \
        sed 's|^--- a/||' | \
        awk '{print $1}' >> "$FILE_LIST.tmp" || true

    # Remove duplicates and sort
    sort -u "$FILE_LIST.tmp" > "$FILE_LIST"
    rm -f "$FILE_LIST.tmp"

    FILE_COUNT=$(wc -l < "$FILE_LIST")
    echo "  Found $FILE_COUNT files in patch"
    echo ""
else
    echo "Step 1: Skipped (file list already exists)"
    FILE_COUNT=$(wc -l < "$FILE_LIST")
    echo "  Using cached list: $FILE_COUNT files"
    echo ""
fi

# Step 2: Apply patch
if [ "$COMMIT_CHROMIUM" = true ]; then
    echo "Step 2: Skipped (--commit-chromium mode, assuming patch already applied)"
    echo ""
elif [ ! -f "$STATE_FILE" ] || ! grep -q "^patch_applied$" "$STATE_FILE" 2>/dev/null; then
    echo "Step 2: Applying patch to $SRC_PATH..."

    # Try dry-run first to check if patch can be applied
    if patch --dry-run -p1 < "$PATCH_FILE" > /dev/null 2>&1; then
        echo "  Dry-run successful, applying patch..."
        patch -p1 < "$PATCH_FILE"
        echo "patch_applied" >> "$STATE_FILE"
        echo "  Patch applied successfully"
    else
        echo "Error: Patch cannot be applied (conflicts or already applied)"
        echo "Checking if patch is already applied..."

        # Check if patch is already applied by using reverse check
        if patch --dry-run -R -p1 < "$PATCH_FILE" > /dev/null 2>&1; then
            echo "  Patch appears to be already applied, continuing..."
            echo "patch_applied" >> "$STATE_FILE"
        else
            echo "Error: Patch has conflicts and cannot be applied"
            exit 1
        fi
    fi
    echo ""

    # Wait for user confirmation before continuing
    echo "Waiting for confirmation..."
    echo "Press any key to continue, or Ctrl+C to abort..."
    read -n 1 -s -r
    echo ""
else
    echo "Step 2: Skipped (patch already applied)"
    echo ""
fi

# Step 3: Load submodule paths from .gitmodules
echo "Step 3: Loading submodule information from .gitmodules..."
declare -A SUBMODULE_MAP
while IFS= read -r submodule_path; do
    [ -z "$submodule_path" ] && continue
    SUBMODULE_MAP["$submodule_path"]=1
done < <(git config --file .gitmodules --get-regexp 'submodule\..*\.path' 2>/dev/null | awk '{print $2}')

SUBMODULE_COUNT=${#SUBMODULE_MAP[@]}
echo "  Loaded $SUBMODULE_COUNT submodules"
echo ""

# Function to determine which repo a file belongs to
get_file_repo() {
    local file_path="$1"

    # Check if file belongs to any submodule
    # We need to check from longest path to shortest to handle nested submodules
    for submodule in $(printf '%s\n' "${!SUBMODULE_MAP[@]}" | awk '{ print length, $0 }' | sort -rn | cut -d" " -f2-); do
        if [[ "$file_path" == "$submodule"/* ]] || [[ "$file_path" == "$submodule" ]]; then
            echo "$submodule"
            return
        fi
    done

    # If not in any submodule, it belongs to main repo
    echo "."
}

# Step 4: Add files to appropriate repositories
echo "Step 4: Adding modified files to git..."

declare -A MAIN_FILES
declare -A SUBMODULE_FILES

while IFS= read -r file_path; do
    [ -z "$file_path" ] && continue

    repo=$(get_file_repo "$file_path")

    if [ "$repo" = "." ]; then
        # Main repository
        MAIN_FILES["$file_path"]=1
    else
        # Submodule - store relative path within submodule
        relative_path="${file_path#$repo/}"
        if [ -z "${SUBMODULE_FILES[$repo]}" ]; then
            SUBMODULE_FILES[$repo]="$relative_path"
        else
            SUBMODULE_FILES[$repo]="${SUBMODULE_FILES[$repo]}|$relative_path"
        fi
    fi
done < "$FILE_LIST"

# Add files to main repository
if [ ${#MAIN_FILES[@]} -gt 0 ]; then
    echo "  Adding ${#MAIN_FILES[@]} files to main repository..."
    for file_path in "${!MAIN_FILES[@]}"; do
        echo "  >>> ${file_path}"
        if [ -f "$file_path" ]; then
            # File exists, add it (new or modified)
            git add --force "$file_path" 2>/dev/null || echo "    Warning: Could not add $file_path"
        else
            # File doesn't exist, check if it's tracked in git
            if git ls-files "$file_path" | grep -q .; then
                # File is tracked but deleted, remove it from git
                git rm --force "$file_path" 2>/dev/null || echo "    Warning: Could not remove $file_path"
            fi
        fi
    done
fi

# Add files to submodules
if [ "$COMMIT_CHROMIUM" = true ]; then
    echo "  Skipping submodule processing (--commit-chromium mode)"
elif [ ${#SUBMODULE_FILES[@]} -gt 0 ]; then
    echo "  Processing ${#SUBMODULE_FILES[@]} submodules..."
    for submodule in "${!SUBMODULE_FILES[@]}"; do
        if [ ! -d "$submodule" ]; then
            echo "    Warning: Submodule directory not found: $submodule"
            continue
        fi

        if [ ! -d "$submodule/.git" ] && [ ! -f "$submodule/.git" ]; then
            echo "    Warning: Not a git repository: $submodule"
            continue
        fi

        echo "    Adding files in submodule: $submodule"
        IFS='|' read -ra files <<< "${SUBMODULE_FILES[$submodule]}"
        for relative_path in "${files[@]}"; do
            echo "    >>> ${relative_path}"
            if [ -f "$submodule/$relative_path" ]; then
                # File exists, add it (new or modified)
                git -C "$submodule" add --force "$relative_path" 2>/dev/null || echo "      Warning: Could not add $relative_path"
            else
                # File doesn't exist, check if it's tracked in git
                if git -C "$submodule" ls-files "$relative_path" | grep -q .; then
                    # File is tracked but deleted, remove it from git
                    git -C "$submodule" rm --force "$relative_path" 2>/dev/null || echo "      Warning: Could not remove $relative_path"
                fi
            fi
        done
    done
fi

echo ""

# Step 5: Commit changes
echo "Step 5: Committing changes..."

COMMIT_MESSAGE="loong64 support

Co-authored-by: Jiajie Chen <c@jia.je>"

# Track commit success
COMMIT_SUCCESS=true

# Commit main repository
if git diff --cached --quiet; then
    echo "  No changes staged in main repository"
else
    echo "  Committing main repository..."
    if ! git commit -m "$COMMIT_MESSAGE"; then
        echo "  Warning: Failed to commit main repository"
        COMMIT_SUCCESS=false
    fi
fi

# Commit submodules
COMMITTED_SUBMODULES=()
if [ "$COMMIT_CHROMIUM" = true ]; then
    echo "  Skipping submodule commits (--commit-chromium mode)"
else
    for submodule in "${!SUBMODULE_FILES[@]}"; do
        if [ ! -d "$submodule" ]; then
            continue
        fi

        if git -C "$submodule" diff --cached --quiet 2>/dev/null; then
            echo "  No changes staged in submodule: $submodule"
        else
            echo "  Committing submodule: $submodule"
            if git -C "$submodule" commit -m "$COMMIT_MESSAGE" 2>/dev/null; then
                COMMITTED_SUBMODULES+=("$submodule")
            else
                echo "    Warning: Failed to commit $submodule"
                COMMIT_SUCCESS=false
            fi
        fi
    done
fi

echo ""

# Step 6: Summary and cleanup
echo "=== Summary ==="
echo "Patch applied successfully: $PATCH_NAME"
echo ""

if [ ${#MAIN_FILES[@]} -gt 0 ]; then
    echo "Main repository: ${#MAIN_FILES[@]} files modified"
fi

if [ ${#COMMITTED_SUBMODULES[@]} -gt 0 ]; then
    echo ""
    echo "Submodules committed:"

    # Save committed submodule paths to file
    SUBMODULES_FILE="$STATE_DIR/${PATCH_NAME}.submodules"
    > "$SUBMODULES_FILE"

    for submodule in "${COMMITTED_SUBMODULES[@]}"; do
        echo "  - $submodule"
        echo "$submodule" >> "$SUBMODULES_FILE"
    done

    echo ""
    echo "Committed submodule paths saved to: $SUBMODULES_FILE"
fi

echo ""

# Clean up state files only if all commits succeeded
if [ "$COMMIT_SUCCESS" = true ]; then
    echo "All commits successful, cleaning up state files..."
    rm -f "$STATE_FILE" "$FILE_LIST"
    echo ""
    echo "Done!"
else
    echo "Some commits failed, keeping state files for retry"
    echo "State files preserved at:"
    echo "  - $STATE_FILE"
    echo "  - $FILE_LIST"
    exit 1
fi

popd
