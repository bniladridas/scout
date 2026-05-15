#!/bin/sh
set -eu

swift build -c release
swift scripts/make-icns.swift

VERSION="$(tr -d '[:space:]' < VERSION)"

APP_DIR=".build/Scout.app"
STAGING_ROOT="${SCOUT_STAGING_ROOT:-/private/tmp/ScoutPackage-$$}"
STAGING="$STAGING_ROOT/Scout.app"
CONTENTS="$STAGING/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf "$STAGING_ROOT"
mkdir -p "$MACOS" "$RESOURCES"

cp ".build/release/Scout" "$MACOS/Scout"
cp "Support/Info.plist" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$CONTENTS/Info.plist"
cp "Support/Resources/AppIcon.icns" "$RESOURCES/AppIcon.icns"
printf "APPL????" > "$CONTENTS/PkgInfo"

xattr -cr "$STAGING"
codesign --force --deep --sign - "$STAGING"

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp -X "$STAGING/Contents/MacOS/Scout" "$APP_DIR/Contents/MacOS/Scout"
cp -X "$STAGING/Contents/Info.plist" "$APP_DIR/Contents/Info.plist"
cp -X "$STAGING/Contents/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
cp -X "$STAGING/Contents/PkgInfo" "$APP_DIR/Contents/PkgInfo"
mkdir -p "$APP_DIR/Contents/_CodeSignature"
cp -X "$STAGING/Contents/_CodeSignature/CodeResources" "$APP_DIR/Contents/_CodeSignature/CodeResources"

xattr -d com.apple.FinderInfo "$APP_DIR" 2>/dev/null || true
xattr -d 'com.apple.fileprovider.fpfs#P' "$APP_DIR" 2>/dev/null || true

if [ "${SCOUT_KEEP_STAGING:-0}" != "1" ]; then
    rm -rf "$STAGING_ROOT"
fi

echo "Created $APP_DIR"
