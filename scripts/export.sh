#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

# Parse command line arguments
EXPORT_CHROMIUM=false
EXPORT_SUBMODULES=false
SUBMODULES_FILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --chromium)
            EXPORT_CHROMIUM=true
            shift
            ;;
        --submodules)
            EXPORT_SUBMODULES=true
            shift
            ;;
        *)
            # Treat as submodules file path
            if [ -z "$SUBMODULES_FILE" ]; then
                SUBMODULES_FILE="$1"
                shift
            else
                echo "Error: Unknown option or multiple file paths provided: $1"
                echo "Usage: $0 [--chromium] [--submodules] [submodules-file]"
                echo "  --chromium         Export chromium patches only"
                echo "  --submodules       Export submodule patches only"
                echo "  submodules-file    Path to file containing submodule paths (one per line)"
                echo ""
                echo "Examples:"
                echo "  $0 --chromium                          # Export chromium only"
                echo "  $0 /path/to/file.submodules            # Export chromium + submodules from file"
                echo "  $0 --submodules /path/to/file.submodules  # Export submodules from file only"
                exit 1
            fi
            ;;
    esac
done

# Validate arguments
if [ "$EXPORT_CHROMIUM" = false ] && [ "$EXPORT_SUBMODULES" = false ] && [ -z "$SUBMODULES_FILE" ]; then
    echo "Error: No operation specified"
    echo "Usage: $0 [--chromium] [--submodules] [submodules-file]"
    echo ""
    echo "You must either:"
    echo "  - Use --chromium to export chromium patches"
    echo "  - Provide a submodules file path"
    echo ""
    echo "Examples:"
    echo "  $0 --chromium                          # Export chromium only"
    echo "  $0 /path/to/file.submodules            # Export chromium + submodules from file"
    echo "  $0 --submodules /path/to/file.submodules  # Export submodules from file only"
    exit 1
fi

# If submodules file is provided but no flags set, export both
if [ -n "$SUBMODULES_FILE" ] && [ "$EXPORT_CHROMIUM" = false ] && [ "$EXPORT_SUBMODULES" = false ]; then
    EXPORT_CHROMIUM=true
    EXPORT_SUBMODULES=true
fi

# If only --chromium flag is set, don't export submodules
if [ "$EXPORT_CHROMIUM" = true ] && [ "$EXPORT_SUBMODULES" = false ] && [ -z "$SUBMODULES_FILE" ]; then
    EXPORT_SUBMODULES=false
fi

# If submodules file is provided, enable submodules export
if [ -n "$SUBMODULES_FILE" ]; then
    EXPORT_SUBMODULES=true

    # Check if file exists
    if [ ! -f "$SUBMODULES_FILE" ]; then
        echo "Error: Submodules file not found: $SUBMODULES_FILE"
        exit 1
    fi
fi

pushd "$SRC_PATH"

if [ "$EXPORT_CHROMIUM" = true ]; then
    echo "=== Exporting Chromium patches ==="

    npx e patches chromium

    echo "Chromium patches exported successfully"
fi

if [ "$EXPORT_SUBMODULES" = true ]; then
    echo "=== Exporting Submodule patches ==="

    echo "Reading submodules from file: $SUBMODULES_FILE"
    CHANGED_SUBMODULES=()
    # Read submodule paths from file
    while IFS= read -r submodule_name; do
        # Skip empty lines
        [ -z "$submodule_name" ] && continue

        # Trim whitespace
        submodule_name=$(echo "$submodule_name" | xargs)
        [ -z "$submodule_name" ] && continue

        echo "Processing submodule from file: $submodule_name"

        # Check if the submodule directory exists and is accessible
        if [ ! -d "$submodule_name" ]; then
            echo "  Warning: Submodule directory not found: $submodule_name"
            continue
        fi

        # Check if it's a valid git repository
        if [ ! -d "$submodule_name/.git" ] && [ ! -f "$submodule_name/.git" ]; then
            echo "  Warning: Not a git repository: $submodule_name"
            continue
        fi

        CHANGED_SUBMODULES+=("$submodule_name")
    done < "$SUBMODULES_FILE"

    # Process config.json and export patches
    if [ ${#CHANGED_SUBMODULES[@]} -gt 0 ]; then
        echo ""
        echo "=== Processing submodule patches ==="

        CONFIG_FILE="electron/patches/config.json"

        # Check if config.json exists
        if [ ! -f "$CONFIG_FILE" ]; then
            echo "Error: $CONFIG_FILE not found"
            exit 1
        fi

        # Function to convert submodule path to patch name
        # Example: third_party/boringssl/src -> boringssl
        get_patch_name() {
            local path="$1"
            # Remove third_party/ prefix
            local name="${path#third_party/}"
            # Remove /src suffix
            name="${name%/src}"
            # Replace - with _
            name="${name//-/_}"
            echo "$name"
        }

        # Track new patches for cleanup
        declare -a NEW_PATCHES=()

        # Process each changed submodule
        for submodule in "${CHANGED_SUBMODULES[@]}"; do
            patch_name=$(get_patch_name "$submodule")
            echo ""
            echo "Processing submodule: $submodule -> patch: $patch_name"

            # Check if this repo already exists in config.json
            repo_exists=$(jq --arg repo "src/$submodule" '[.[] | select(.repo == $repo)] | length' "$CONFIG_FILE")

            if [ "$repo_exists" = "0" ]; then
                echo "  Adding new entry to config.json"

                # Add new entry to config.json
                jq --arg patch_dir "src/electron/patches/$patch_name" \
                   --arg repo "src/$submodule" \
                   '. += [{"patch_dir": $patch_dir, "repo": $repo}]' \
                   "$CONFIG_FILE" > "$CONFIG_FILE.tmp"
                mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

                # Track this as a new patch for cleanup
                NEW_PATCHES+=("$patch_name")
            else
                echo "  Entry already exists in config.json"
            fi

            # Export patches using electron build tools
            echo "  Running: npx e patches $patch_name"
            npx e patches "$patch_name" || echo "  Warning: Failed to export patches for $patch_name"
        done

        # Clean up new patches - only keep loong64_support.patch
        if [ ${#NEW_PATCHES[@]} -gt 0 ]; then
            echo ""
            echo "=== Cleaning up new patch directories ==="

            for patch_name in "${NEW_PATCHES[@]}"; do
                patch_dir="electron/patches/$patch_name"

                if [ ! -d "$patch_dir" ]; then
                    echo "  Warning: Patch directory not found: $patch_dir"
                    continue
                fi

                echo "  Cleaning $patch_dir"

                # Overwrite .patches file with only loong64_support.patch
                echo "loong64_support.patch" > "$patch_dir/.patches"

                # Remove all .patch files except loong64_support.patch
                find "$patch_dir" -name "*.patch" -not -name "loong64_support.patch" -type f -delete

                echo "    Kept only: loong64_support.patch"
            done
        fi

        # Print summary
        echo ""
        echo "=== Summary ==="
        echo "Changed submodules:"
        for submodule in "${CHANGED_SUBMODULES[@]}"; do
            patch_name=$(get_patch_name "$submodule")
            echo "  - $submodule -> $patch_name"
        done

        if [ ${#NEW_PATCHES[@]} -gt 0 ]; then
            echo ""
            echo "New patches added:"
            for patch_name in "${NEW_PATCHES[@]}"; do
                echo "  - $patch_name"
            done
        fi
    else
        echo ""
        echo "No submodules have changes."
    fi
fi

popd