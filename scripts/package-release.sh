#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="ImmichSync"
DIST_DIR="$ROOT_DIR/dist"
STAGE_DIR="$DIST_DIR/release"
DMG_STAGE="$DIST_DIR/dmg-stage"
DMG_TEMP="$DIST_DIR/${APP_NAME}-temp.dmg"
MOUNT_DIR="$DIST_DIR/.mnt-${APP_NAME}"
DMG_BG="$ROOT_DIR/scripts/dmg-background.png"
DMG_NAME="$APP_NAME.dmg"
ZIP_NAME="$APP_NAME.zip"

cd "$ROOT_DIR"

./scripts/build-app.sh

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
cp -R "$DIST_DIR/${APP_NAME}.app" "$STAGE_DIR/${APP_NAME}.app"

# Prepare DMG staging folder with Applications symlink
rm -rf "$DMG_STAGE"
mkdir -p "$DMG_STAGE"
cp -R "$DIST_DIR/${APP_NAME}.app" "$DMG_STAGE/${APP_NAME}.app"
ln -s /Applications "$DMG_STAGE/Applications"

rm -f "$DIST_DIR/$DMG_NAME" "$DIST_DIR/$ZIP_NAME"

# Create ZIP
( cd "$STAGE_DIR" && /usr/bin/zip -qry "$DIST_DIR/$ZIP_NAME" "$APP_NAME.app" )

# Create a writable DMG, customize Finder window, then convert to compressed
/usr/bin/hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_STAGE" -ov -format UDRW "$DMG_TEMP" >/dev/null
mkdir -p "$MOUNT_DIR"
/usr/bin/hdiutil attach "$DMG_TEMP" -mountpoint "$MOUNT_DIR" -nobrowse -noverify -noautoopen >/dev/null

# Optional background files (not using Finder scripting to avoid auto-open issues)
mkdir -p "$MOUNT_DIR/.background"
cp "$DMG_BG" "$MOUNT_DIR/.background/background.png"

/usr/bin/hdiutil detach "$MOUNT_DIR" >/dev/null || /usr/bin/hdiutil detach -force "$MOUNT_DIR" >/dev/null
/usr/bin/hdiutil convert "$DMG_TEMP" -format UDZO -o "$DIST_DIR/$DMG_NAME" >/dev/null
rm -f "$DMG_TEMP"

echo "Created: $DIST_DIR/$ZIP_NAME"
echo "Created: $DIST_DIR/$DMG_NAME"
