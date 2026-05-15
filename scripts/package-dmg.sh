#!/bin/sh
set -eu

STAGING_ROOT="/private/tmp/ScoutDmg-$$"
VERSION="$(tr -d '[:space:]' < VERSION)"
APP_NAME="Scout.app"
APP_PATH="$STAGING_ROOT/$APP_NAME"
VOLUME_ROOT="$STAGING_ROOT/volume"
DMG_PATH=".build/Scout.dmg"
ROOT_DMG_PATH="Scout.dmg"

SCOUT_STAGING_ROOT="$STAGING_ROOT" \
SCOUT_KEEP_STAGING=1 \
scripts/package-app.sh

mkdir -p "$VOLUME_ROOT"
cp -R "$APP_PATH" "$VOLUME_ROOT/$APP_NAME"
ln -s /Applications "$VOLUME_ROOT/Applications"

xattr -cr "$VOLUME_ROOT"
codesign --verify --deep --strict "$VOLUME_ROOT/$APP_NAME"

rm -f "$DMG_PATH"
hdiutil create \
    -volname "Scout $VERSION" \
    -srcfolder "$VOLUME_ROOT" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGING_ROOT"

cp "$DMG_PATH" "$ROOT_DMG_PATH"

echo "Created $DMG_PATH"
echo "Created $ROOT_DMG_PATH"
