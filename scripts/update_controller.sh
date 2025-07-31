#!/bin/bash
set -e

# Always run from repo root, not scripts/ folder
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# Config
SOURCE_REPO="https://github.com/IAmMarcelJung/fabulous_usb.git"
SOURCE_SUBDIR="controller"
TMP_DIR=".tmp_controller"
TARGET_DIR="ip/$SOURCE_SUBDIR"

echo "🔄 Syncing '$SOURCE_SUBDIR' from $SOURCE_REPO into '$TARGET_DIR'..."

# Clean temp and target directories
rm -rf "$TMP_DIR"
rm -rf "$TARGET_DIR"

# Clone repo with sparse checkout
git clone --depth=1 --filter=blob:none --sparse "$SOURCE_REPO" "$TMP_DIR"
cd "$TMP_DIR"
git sparse-checkout set "$SOURCE_SUBDIR"

# Copy controller into ip/
cd "$REPO_ROOT"
mkdir -p "$(dirname $TARGET_DIR)"
cp -r "$TMP_DIR/$SOURCE_SUBDIR" "$TARGET_DIR"

# Clean up
rm -rf "$TMP_DIR"

echo "✅ '$SOURCE_SUBDIR' synced into '$TARGET_DIR'"
