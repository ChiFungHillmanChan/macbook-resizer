#!/usr/bin/env bash
set -euo pipefail

# build-dmg.sh — produces a universal, ad-hoc-signed Scene DMG at dist/.
# Usage: ./scripts/build-dmg.sh [version]
#        version defaults to the value embedded in MARKETING_VERSION or 0.1.0.

VERSION="${1:-0.1.0}"
PROJECT="SceneApp/SceneApp.xcodeproj"
SCHEME="SceneApp"
BUILD_DIR="build"
DIST_DIR="dist"
APP_NAME="Scene.app"
DMG_NAME="Scene-${VERSION}.dmg"
VOLUME_NAME="Scene ${VERSION}"

echo "==> Cleaning previous build…"
rm -rf "$BUILD_DIR" "$DIST_DIR"

echo "==> Building universal Release binary (arm64 + x86_64)…"
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    build >/dev/null

SRC_APP="$BUILD_DIR/Build/Products/Release/SceneApp.app"
if [[ ! -d "$SRC_APP" ]]; then
    echo "ERROR: build did not produce $SRC_APP" >&2
    exit 1
fi

ICON_ICNS="dist/Scene.icns"

echo "==> Staging DMG contents…"
mkdir -p "$DIST_DIR/dmg-contents"
cp -R "$SRC_APP" "$DIST_DIR/dmg-contents/$APP_NAME"
ln -s /Applications "$DIST_DIR/dmg-contents/Applications"

if [[ -f "$ICON_ICNS" ]]; then
    cp "$ICON_ICNS" "$DIST_DIR/dmg-contents/.VolumeIcon.icns"
fi

echo "==> Packaging DMG…"
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$DIST_DIR/dmg-contents" \
    -ov \
    -format UDZO \
    "$DIST_DIR/$DMG_NAME" >/dev/null

if [[ -f "$ICON_ICNS" ]]; then
    echo "==> Setting DMG volume icon…"
    MOUNT_DIR=$(hdiutil attach "$DIST_DIR/$DMG_NAME" -readwrite -noverify -noautoopen 2>/dev/null | grep "Volumes" | awk '{print $3}')
    if [[ -n "$MOUNT_DIR" ]]; then
        cp "$ICON_ICNS" "$MOUNT_DIR/.VolumeIcon.icns"
        SetFile -a C "$MOUNT_DIR" 2>/dev/null || true
        hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1
    fi
fi

hdiutil verify "$DIST_DIR/$DMG_NAME" >/dev/null

rm -rf "$DIST_DIR/dmg-contents"

echo
echo "==> Done."
echo "    $DIST_DIR/$DMG_NAME"
du -h "$DIST_DIR/$DMG_NAME"
