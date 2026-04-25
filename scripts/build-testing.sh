#!/bin/zsh
#
# build-testing.sh — produces a side-by-side `Scene-testing.app` for V0.6/V0.7
# manual smoke testing without disturbing the user's installed `Scene.app`.
#
# What's different from a production build:
#   - PRODUCT_NAME           : Scene-testing  (binary + .app named Scene-testing)
#   - PRODUCT_BUNDLE_IDENTIFIER : com.hillman.SceneApp.testing
#       → fresh AX TCC entry, separate UserDefaults, separate Launch Services
#   - Application Support    : ~/Library/Application Support/Scene-testing/
#       → AppDelegate.applicationSupportFolderName() detects the .testing
#         suffix and routes layouts.json / settings.json / workspaces.json /
#         diagnostics/ into the parallel folder
#
# Usage:
#     ./scripts/build-testing.sh         # build only
#     ./scripts/build-testing.sh --run   # build then `open dist/Scene-testing.app`
#
# Hotkey collisions:
#     The seeded layout chords (⌘⌃1-9,0) collide between Scene.app and
#     Scene-testing.app. Quit production Scene before launching testing:
#         killall SceneApp 2>/dev/null; true

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DERIVED="build/testing"
PRODUCT_NAME="Scene-testing"
BUNDLE_ID="com.hillman.SceneApp.testing"
DEST_DIR="dist"
DEST_APP="$DEST_DIR/$PRODUCT_NAME.app"

echo "Building $PRODUCT_NAME (bundle ID: $BUNDLE_ID)"
xcodebuild \
    -project SceneApp/SceneApp.xcodeproj \
    -scheme SceneApp \
    -configuration Debug \
    -derivedDataPath "$DERIVED" \
    PRODUCT_NAME="$PRODUCT_NAME" \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_ALLOWED=NO \
    build \
    | tail -25

BUILT_APP="$DERIVED/Build/Products/Debug/$PRODUCT_NAME.app"
if [[ ! -d "$BUILT_APP" ]]; then
    echo ""
    echo "ERROR: build product not found at $BUILT_APP"
    exit 1
fi

mkdir -p "$DEST_DIR"
rm -rf "$DEST_APP"
cp -R "$BUILT_APP" "$DEST_APP"

echo ""
echo "Built : $ROOT/$DEST_APP"
echo "  Bundle ID         : $BUNDLE_ID"
echo "  Support directory : ~/Library/Application Support/Scene-testing/"
echo "  Hotkeys           : seed defaults will collide with production Scene"
echo ""

if [[ "${1:-}" == "--run" ]]; then
    killall SceneApp 2>/dev/null || true
    open "$DEST_APP"
    echo "Launched. First run grants AX as 'Scene-testing' (fresh TCC entry)."
fi
