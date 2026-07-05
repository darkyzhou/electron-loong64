#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

EXPORT_CHROMIUM=false
EXPORT_SUBMODULES=false
RUN_LINT=true
SUBMODULES_FILE=""

usage() {
    cat <<'EOF'
Usage: scripts/export.sh [--chromium] [--submodules] [--no-lint] [submodules-file]

Options:
  --chromium         Export Chromium main-repo patches.
  --submodules       Export patches for submodules listed in submodules-file.
  --no-lint          Skip `node script/lint.js --patches --only --`.
  submodules-file    File containing changed submodule paths, one per line.

Examples:
  scripts/export.sh --chromium
  scripts/export.sh changed.submodules
  scripts/export.sh --submodules changed.submodules
  scripts/export.sh --chromium --submodules changed.submodules
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --chromium)
            EXPORT_CHROMIUM=true
            shift
            ;;
        --submodules)
            EXPORT_SUBMODULES=true
            shift
            ;;
        --no-lint)
            RUN_LINT=false
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            if [[ -z "$SUBMODULES_FILE" ]]; then
                SUBMODULES_FILE="$1"
                shift
            else
                echo "Error: unknown option or multiple submodule files: $1" >&2
                usage >&2
                exit 2
            fi
            ;;
    esac
done

# Passing a submodule file without explicit flags keeps the old convenient
# behavior: export Chromium and the listed submodule patch sets.
if [[ -n "$SUBMODULES_FILE" && "$EXPORT_CHROMIUM" == false && "$EXPORT_SUBMODULES" == false ]]; then
    EXPORT_CHROMIUM=true
    EXPORT_SUBMODULES=true
fi

if [[ "$EXPORT_CHROMIUM" == false && "$EXPORT_SUBMODULES" == false ]]; then
    echo "Error: no export target specified" >&2
    usage >&2
    exit 2
fi

if [[ "$EXPORT_SUBMODULES" == true ]]; then
    if [[ -z "$SUBMODULES_FILE" ]]; then
        echo "Error: --submodules requires a submodules-file" >&2
        usage >&2
        exit 2
    fi
    if [[ ! -f "$SUBMODULES_FILE" ]]; then
        echo "Error: submodules file not found: $SUBMODULES_FILE" >&2
        exit 1
    fi
    SUBMODULES_FILE="$(realpath "$SUBMODULES_FILE")"
fi

normalize_submodule_path() {
    local path="$1"
    path="${path#src/}"
    path="${path%/}"
    printf '%s\n' "$path"
}

fallback_patch_name() {
    local path="$1"
    local name="${path#third_party/}"
    name="${name%/src}"
    name="${name//-/_}"
    name="${name//\//_}"
    printf '%s\n' "$name"
}

patch_name_for_submodule() {
    local config_file="$1"
    local submodule="$2"
    local repo="src/$submodule"
    local patch_name

    patch_name="$(jq -r --arg repo "$repo" '
        first(.[] | select(.repo == $repo) | .patch_dir | sub("^src/electron/patches/"; "")) // empty
    ' "$config_file")"

    if [[ -n "$patch_name" ]]; then
        printf '%s\n' "$patch_name"
    else
        fallback_patch_name "$submodule"
    fi
}

ensure_config_entry() {
    local config_file="$1"
    local submodule="$2"
    local patch_name="$3"
    local repo="src/$submodule"
    local exists

    exists="$(jq --arg repo "$repo" '[.[] | select(.repo == $repo)] | length' "$config_file")"
    if [[ "$exists" != "0" ]]; then
        echo "  Entry already exists in $config_file"
        return
    fi

    echo "  Adding entry to $config_file"
    jq --arg patch_dir "src/electron/patches/$patch_name" \
       --arg repo "$repo" \
       '. += [{"patch_dir": $patch_dir, "repo": $repo}]' \
       "$config_file" > "$config_file.tmp"
    mv "$config_file.tmp" "$config_file"
}

run_patch_lint() {
    if [[ "$RUN_LINT" != true ]]; then
        echo "=== Skipping patch lint (--no-lint) ==="
        return
    fi

    echo "=== Running patch lint ==="
    (cd electron && node script/lint.js --patches --only --)
}

EXPORTED_PATCH_SETS=()

pushd "$SRC_PATH" >/dev/null

if [[ "$EXPORT_CHROMIUM" == true ]]; then
    echo "=== Exporting Chromium patches ==="
    npx e patches chromium
    EXPORTED_PATCH_SETS+=(chromium)
fi

if [[ "$EXPORT_SUBMODULES" == true ]]; then
    echo "=== Exporting submodule patches ==="
    echo "Reading submodules from: $SUBMODULES_FILE"

    CONFIG_FILE="electron/patches/config.json"
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "Error: $CONFIG_FILE not found" >&2
        exit 1
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Allow empty lines and comments in the submodules file.
        line="${line%%#*}"
        submodule="$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [[ -z "$submodule" ]] && continue

        submodule="$(normalize_submodule_path "$submodule")"
        if [[ ! -d "$submodule" ]]; then
            echo "  Warning: submodule directory not found: $submodule" >&2
            continue
        fi
        if [[ ! -d "$submodule/.git" && ! -f "$submodule/.git" ]]; then
            echo "  Warning: not a git repository: $submodule" >&2
            continue
        fi

        patch_name="$(patch_name_for_submodule "$CONFIG_FILE" "$submodule")"
        echo ""
        echo "Processing submodule: $submodule -> $patch_name"
        ensure_config_entry "$CONFIG_FILE" "$submodule" "$patch_name"

        echo "  Running: npx e patches $patch_name"
        npx e patches "$patch_name"
        EXPORTED_PATCH_SETS+=("$patch_name")
    done < "$SUBMODULES_FILE"
fi

run_patch_lint

popd >/dev/null

echo "=== Export summary ==="
if [[ ${#EXPORTED_PATCH_SETS[@]} -eq 0 ]]; then
    echo "No patch sets exported."
else
    for patch_set in "${EXPORTED_PATCH_SETS[@]}"; do
        echo "- npx e patches $patch_set"
    done
fi
