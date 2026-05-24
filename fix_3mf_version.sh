#!/usr/bin/env bash
set -euo pipefail

# fix_3mf_version.sh
# Fix Bambu Studio 3MF files for MakerWorld compatibility by downgrading
# the embedded version metadata to the latest official (non-beta) release.

SCRIPT_NAME="$(basename "$0")"

usage() {
    echo "Usage: $SCRIPT_NAME <3mf_file>"
    echo ""
    echo "  Modifies a Bambu Studio .3mf file to claim it was created with the"
    echo "  latest official stable release, bypassing MakerWorld's beta-version"
    echo "  rejection. Outputs a new file next to the original:"
    echo "    <original>_fixed.3mf"
    echo ""
    echo "  The original file is never modified."
    exit 1
}

if [[ $# -ne 1 ]]; then
    usage
fi

INPUT_FILE="$1"

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: File not found: $INPUT_FILE" >&2
    exit 1
fi

if [[ ! "$INPUT_FILE" =~ \.3mf$ ]]; then
    echo "Error: Input file must have .3mf extension" >&2
    exit 1
fi

# Resolve to absolute path
INPUT_FILE="$(realpath "$INPUT_FILE")"
OUTPUT_FILE="${INPUT_FILE%.3mf}_fixed.3mf"

if [[ -f "$OUTPUT_FILE" ]]; then
    echo "Warning: Output file already exists and will be overwritten: $OUTPUT_FILE" >&2
fi

echo "=== Bambu Studio 3MF Version Fixer ==="
echo "Input:  $INPUT_FILE"

# --- Step 1: Fetch latest official release from GitHub ---
echo ""
echo "Fetching latest official Bambu Studio release from GitHub..."

# GitHub API endpoint for latest release (stable)
LATEST_TAG=$(curl -sL --fail \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/bambulab/BambuStudio/releases/latest" \
    | jq -r '.tag_name // empty')

if [[ -z "$LATEST_TAG" ]]; then
    echo "Error: Failed to fetch latest release from GitHub API" >&2
    exit 1
fi

# Convert tag (e.g., v02.06.00.51) to version string (02.06.00.51)
TARGET_VERSION="${LATEST_TAG#v}"
echo "Latest official release: $TARGET_VERSION (tag: $LATEST_TAG)"

# --- Step 2: Extract 3MF to temp directory ---
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

unzip -q "$INPUT_FILE" -d "$TMPDIR"
echo "Extracted 3MF archive to temporary directory"

# --- Step 3: Detect current version from metadata ---
# We read the version from project_settings.config (JSON "version" field)
# as the canonical source, but we also need to know the 3dmodel.model format.

detect_version() {
    local file="$1"
    if [[ -f "$file" ]]; then
        grep -oP '"version"\s*:\s*"\K[^"]+' "$file" 2>/dev/null || true
    fi
}

detect_app_version() {
    local file="$1"
    if [[ -f "$file" ]]; then
        grep -oP '<metadata name="Application">BambuStudio-\K[^<]+' "$file" 2>/dev/null || true
    fi
}

detect_slice_version() {
    local file="$1"
    if [[ -f "$file" ]]; then
        grep -oP 'value="\K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$file" 2>/dev/null || true
    fi
}

CURRENT_VERSION=""

# Try project_settings.config first
if [[ -f "$TMPDIR/Metadata/project_settings.config" ]]; then
    CURRENT_VERSION=$(detect_version "$TMPDIR/Metadata/project_settings.config")
fi

# Fallback to slice_info.config
if [[ -z "$CURRENT_VERSION" && -f "$TMPDIR/Metadata/slice_info.config" ]]; then
    CURRENT_VERSION=$(detect_slice_version "$TMPDIR/Metadata/slice_info.config")
fi

# Fallback to 3dmodel.model
if [[ -z "$CURRENT_VERSION" && -f "$TMPDIR/3D/3dmodel.model" ]]; then
    CURRENT_VERSION=$(detect_app_version "$TMPDIR/3D/3dmodel.model")
fi

if [[ -z "$CURRENT_VERSION" ]]; then
    echo "Error: Could not detect current Bambu Studio version in the 3MF file" >&2
    echo "       (tried: Metadata/project_settings.config, Metadata/slice_info.config, 3D/3dmodel.model)" >&2
    exit 1
fi

echo "Detected version in 3MF: $CURRENT_VERSION"

if [[ "$CURRENT_VERSION" == "$TARGET_VERSION" ]]; then
    echo ""
    echo "Version already matches latest official release. Nothing to do."
    cp "$INPUT_FILE" "$OUTPUT_FILE"
    echo "Output:  $OUTPUT_FILE"
    exit 0
fi

# --- Step 4: Replace version strings in all relevant files ---

echo ""
echo "Replacing version $CURRENT_VERSION -> $TARGET_VERSION ..."

FILES_TO_PATCH=(
    "$TMPDIR/3D/3dmodel.model"
    "$TMPDIR/Metadata/slice_info.config"
    "$TMPDIR/Metadata/project_settings.config"
)

PATTERN_PLAIN="$CURRENT_VERSION"
PATTERN_APP="BambuStudio-$CURRENT_VERSION"
REPLACE_APP="BambuStudio-$TARGET_VERSION"

PATCHED_COUNT=0

for f in "${FILES_TO_PATCH[@]}"; do
    if [[ ! -f "$f" ]]; then
        continue
    fi

    CHANGED=0

    # Replace plain version string (e.g., in slice_info.config and project_settings.config)
    if grep -qF "$PATTERN_PLAIN" "$f"; then
        sed -i "s/$PATTERN_PLAIN/$TARGET_VERSION/g" "$f"
        CHANGED=1
    fi

    # Replace Application metadata format (e.g., BambuStudio-02.07.00.55)
    if grep -qF "$PATTERN_APP" "$f"; then
        sed -i "s/$PATTERN_APP/$REPLACE_APP/g" "$f"
        CHANGED=1
    fi

    if [[ "$CHANGED" -eq 1 ]]; then
        PATCHED_COUNT=$((PATCHED_COUNT + 1))
        echo "  Patched: ${f#$TMPDIR/}"
    fi
done

if [[ "$PATCHED_COUNT" -eq 0 ]]; then
    echo "Warning: No version strings were found to replace. File may use an unexpected format." >&2
fi

# --- Step 5: Repackage the 3MF file ---
# 3MF is a ZIP archive. We must preserve the exact structure.
# We rebuild it from the temp directory, using -X to avoid extra ZIP metadata.

echo ""
echo "Repackaging 3MF archive..."

# Change to temp dir and zip with correct relative paths
cd "$TMPDIR"
zip -rqX "$OUTPUT_FILE" .
cd - >/dev/null

echo ""
echo "Done!"
echo "Output:  $OUTPUT_FILE"
echo ""
echo "You can now upload '$OUTPUT_FILE' to MakerWorld."
