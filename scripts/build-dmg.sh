#!/usr/bin/env bash
set -euo pipefail

# build-dmg.sh — produces an arm64, Developer ID-signed, notarized Scene DMG
# at dist/.
#
# Produces a polished two-icon installer window (Scene.app on the left,
# Applications folder alias on the right) with a background image showing a
# directional arrow. AppleScript pins window bounds, icon positions, icon
# size, and hides toolbar/sidebar/status bar so the user sees a clean
# "drag-me-over-there" layout.
#
# Background image lives at dmg/background.tiff (committed to the repo).
#
# Signing + notarization:
# - App signed with Developer ID Application certificate from login keychain.
# - Notarization uses the "scene-notary" keychain profile created via
#     xcrun notarytool store-credentials "scene-notary" \
#         --apple-id <id> --team-id <TEAM> --password <app-specific-pw>
# - Set SKIP_NOTARY=1 to skip the Apple notary submission (ad-hoc only).
#   Useful for local DMG-layout iteration where you don't care about
#   Gatekeeper acceptance.
#
# Usage:
#   ./scripts/build-dmg.sh 0.5.0              # full notarized release
#   SKIP_NOTARY=1 ./scripts/build-dmg.sh 0.5.0-dev  # local test, ad-hoc

VERSION="${1:-0.1.0}"
PROJECT="SceneApp/SceneApp.xcodeproj"
SCHEME="SceneApp"
BUILD_DIR="build"
DIST_DIR="dist"
STAGE_DIR="$DIST_DIR/dmg-contents"
APP_NAME="Scene.app"
DMG_NAME="Scene-${VERSION}.dmg"
DMG_RW="$DIST_DIR/Scene-${VERSION}-rw.dmg"
VOLUME_NAME="Scene ${VERSION}"

ICON_ICNS="$DIST_DIR/Scene.icns"
BG_TIFF="dmg/background.tiff"

DEVELOPER_ID="Developer ID Application: Hillman Chan (22K6G3HH9G)"
TEAM_ID="22K6G3HH9G"
NOTARY_PROFILE="scene-notary"
SKIP_NOTARY="${SKIP_NOTARY:-0}"

echo "==> Cleaning previous build artifacts…"
rm -rf "$BUILD_DIR" "$STAGE_DIR" "$DIST_DIR/$DMG_NAME" "$DMG_RW"
mkdir -p "$DIST_DIR"

if [[ "$SKIP_NOTARY" == "1" ]]; then
    echo "==> SKIP_NOTARY=1 — ad-hoc signing (Apple notary skipped)"
    SIGN_IDENTITY="-"
    EXTRA_SIGN_FLAGS=""
else
    echo "==> Developer ID signing ($DEVELOPER_ID)"
    SIGN_IDENTITY="$DEVELOPER_ID"
    EXTRA_SIGN_FLAGS="--timestamp --options=runtime"
fi

echo "==> Building arm64 Release binary (Apple Silicon only)…"
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    OTHER_CODE_SIGN_FLAGS="$EXTRA_SIGN_FLAGS" \
    ARCHS="arm64" \
    VALID_ARCHS="arm64" \
    ONLY_ACTIVE_ARCH=NO \
    build >/dev/null

SRC_APP="$BUILD_DIR/Build/Products/Release/SceneApp.app"
if [[ ! -d "$SRC_APP" ]]; then
    echo "ERROR: build did not produce $SRC_APP" >&2
    exit 1
fi

echo "==> Staging DMG contents…"
mkdir -p "$STAGE_DIR"
cp -R "$SRC_APP" "$STAGE_DIR/$APP_NAME"
ln -s /Applications "$STAGE_DIR/Applications"

# Background image + volume icon go into hidden dotfiles that Finder understands.
if [[ -f "$BG_TIFF" ]]; then
    mkdir -p "$STAGE_DIR/.background"
    cp "$BG_TIFF" "$STAGE_DIR/.background/background.tiff"
else
    echo "WARN: $BG_TIFF not found — DMG will use Finder default (no background)." >&2
fi
if [[ -f "$ICON_ICNS" ]]; then
    cp "$ICON_ICNS" "$STAGE_DIR/.VolumeIcon.icns"
fi

# Create an intermediate READ-WRITE DMG we can mount, style via AppleScript,
# and then compress. Going straight to ULFO would give us a compressed but
# unstyled DMG.
#
# Size: stage + 30% headroom, rounded up. hdiutil can auto-size but it
# sometimes reserves too little for .DS_Store writes.
STAGE_BYTES=$(du -sk "$STAGE_DIR" | awk '{print $1}')
DMG_KB=$(( STAGE_BYTES + STAGE_BYTES / 3 + 2048 ))
echo "==> Creating intermediate R/W DMG (~${DMG_KB}K)…"
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGE_DIR" \
    -fs HFS+ \
    -format UDRW \
    -size "${DMG_KB}k" \
    -ov \
    "$DMG_RW" >/dev/null

echo "==> Mounting R/W DMG to apply Finder layout…"
MOUNT_OUT=$(hdiutil attach "$DMG_RW" -readwrite -noverify -noautoopen)
MOUNT_DIR=$(echo "$MOUNT_OUT" | grep "/Volumes/" | awk '{for (i=3; i<=NF; i++) printf "%s ", $i; print ""}' | sed 's/ *$//' | head -1)
if [[ -z "$MOUNT_DIR" || ! -d "$MOUNT_DIR" ]]; then
    echo "ERROR: could not determine mount point from hdiutil output:" >&2
    echo "$MOUNT_OUT" >&2
    exit 1
fi
echo "    mounted at: $MOUNT_DIR"

# Hide the .background folder and volume icon from Finder's normal view.
if [[ -d "$MOUNT_DIR/.background" ]]; then
    SetFile -a V "$MOUNT_DIR/.background" 2>/dev/null || true
fi
if [[ -f "$MOUNT_DIR/.VolumeIcon.icns" ]]; then
    SetFile -a VC "$MOUNT_DIR/.VolumeIcon.icns" 2>/dev/null || true
    SetFile -a C "$MOUNT_DIR" 2>/dev/null || true
fi

# Finder layout via AppleScript. Window is 660x400 content at screen position
# (400, 200). Scene.app sits at (164, 200) and the Applications alias at
# (497, 200) — 128px icons with a 333px gap that matches the arrow glyph in
# the background image.
echo "==> Applying Finder layout…"
osascript <<EOF || true
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 200, 1060, 620}
        set viewOpts to the icon view options of container window
        set arrangement of viewOpts to not arranged
        set icon size of viewOpts to 128
        set text size of viewOpts to 13
        set label position of viewOpts to bottom
        try
            set background picture of viewOpts to file ".background:background.tiff"
        end try
        set position of item "$APP_NAME" of container window to {164, 200}
        set position of item "Applications" of container window to {497, 200}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

sync

echo "==> Detaching R/W DMG…"
# hdiutil occasionally reports the volume as busy right after AppleScript
# runs (Finder hasn't released it yet). Retry a few times before giving up.
for attempt in 1 2 3 4 5; do
    if hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1; then
        break
    fi
    sleep 1
    [[ $attempt -eq 5 ]] && hdiutil detach "$MOUNT_DIR" -force >/dev/null 2>&1 || true
done

echo "==> Converting to compressed read-only DMG (ULFO/LZFSE)…"
hdiutil convert "$DMG_RW" \
    -format ULFO \
    -o "$DIST_DIR/$DMG_NAME" >/dev/null
rm -f "$DMG_RW"

hdiutil verify "$DIST_DIR/$DMG_NAME" >/dev/null

if [[ "$SKIP_NOTARY" == "0" ]]; then
    echo "==> Signing DMG itself with Developer ID…"
    codesign --force --sign "$DEVELOPER_ID" --timestamp "$DIST_DIR/$DMG_NAME"

    echo "==> Submitting DMG to Apple notary service…"
    echo "    (通常 2-10 分鐘，唔好 interrupt。)"
    xcrun notarytool submit "$DIST_DIR/$DMG_NAME" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait

    echo "==> Stapling notary ticket to DMG…"
    xcrun stapler staple "$DIST_DIR/$DMG_NAME"

    echo "==> Verifying Gatekeeper acceptance…"
    spctl --assess --type open --context context:primary-signature \
        --verbose=4 "$DIST_DIR/$DMG_NAME"
else
    echo "==> SKIP_NOTARY=1 — ad-hoc signing DMG, skipping notary submission"
    codesign --force --sign "-" "$DIST_DIR/$DMG_NAME"
fi

# Keep dist/dmg-contents out of the repo, but its layout is small — nothing
# user-facing references it past this point.
rm -rf "$STAGE_DIR"

echo
echo "==> Done."
echo "    $DIST_DIR/$DMG_NAME"
du -h "$DIST_DIR/$DMG_NAME"
