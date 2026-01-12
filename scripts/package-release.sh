#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="ImmichSync"
DIST_DIR="$ROOT_DIR/dist"
STAGE_DIR="$DIST_DIR/release"
DMG_NAME="$APP_NAME.dmg"
ZIP_NAME="$APP_NAME.zip"

cd "$ROOT_DIR"

./scripts/build-app.sh

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
cp -R "$DIST_DIR/${APP_NAME}.app" "$STAGE_DIR/${APP_NAME}.app"

rm -f "$DIST_DIR/$DMG_NAME" "$DIST_DIR/$ZIP_NAME"

# Create ZIP
( cd "$STAGE_DIR" && /usr/bin/zip -qry "$DIST_DIR/$ZIP_NAME" "$APP_NAME.app" )

# Create DMG (unsigned)
/usr/bin/hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE_DIR" -ov -format UDZO "$DIST_DIR/$DMG_NAME" >/dev/null

echo "Created: $DIST_DIR/$ZIP_NAME"
echo "Created: $DIST_DIR/$DMG_NAME"
