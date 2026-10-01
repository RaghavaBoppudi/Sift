#!/bin/bash
# Copies the freshly built, already-signed app into /Applications.
# Runs as an Xcode scheme post-action, so the build settings below are set.
set -euo pipefail

SRC="${BUILT_PRODUCTS_DIR}/${FULL_PRODUCT_NAME}"
DEST="/Applications/${FULL_PRODUCT_NAME}"

[ -d "$SRC" ] || { echo "Nothing to install: $SRC not found"; exit 0; }

# Quit only the installed copy, not the instance Xcode may be debugging.
pkill -f "^${DEST}/Contents/MacOS/" 2>/dev/null || true
sleep 0.5

rm -rf "$DEST"
ditto "$SRC" "$DEST"
echo "Installed $DEST"
