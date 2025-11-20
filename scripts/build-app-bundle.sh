#!/bin/bash
set -euo pipefail

APP_NAME="TypeClipboard"
EXECUTABLE_NAME="TypeClipboardApp"
IDENTIFIER="com.example.typeclipboard"
VERSION=${VERSION:-1.0.0}
BUILD=${BUILD:-1}

ROOT_DIR=$(cd "$(dirname "$0")"/.. && pwd)
BUILD_DIR="$ROOT_DIR/.build/release"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
INFO_PLIST_TEMPLATE="$ROOT_DIR/Packaging/Info.plist"
ICON_FILE="$ROOT_DIR/Sources/TypeClipboardApp/Resources/AppIcon.icns"

printf "\n▶︎ Building release binary...\n"
swift build -c release

printf "\n▶︎ Assembling app bundle at %s\n" "$APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR"

cp "$BUILD_DIR/$EXECUTABLE_NAME" "$MACOS_DIR/$EXECUTABLE_NAME"
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"

if [ ! -f "$INFO_PLIST_TEMPLATE" ]; then
  echo "Missing Info.plist template at $INFO_PLIST_TEMPLATE" >&2
  exit 1
fi

cp "$INFO_PLIST_TEMPLATE" "$CONTENTS_DIR/Info.plist"
plutil -replace CFBundleIdentifier -string "$IDENTIFIER" "$CONTENTS_DIR/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD" "$CONTENTS_DIR/Info.plist"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$CONTENTS_DIR/Info.plist"

if [ -f "$ICON_FILE" ]; then
  cp "$ICON_FILE" "$RESOURCES_DIR/AppIcon.icns"
else
  echo "Warning: AppIcon.icns missing; using generic icon" >&2
fi

/usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 13.0" "$CONTENTS_DIR/Info.plist" >/dev/null 2>&1 || true

printf "▶︎ Embedding Swift runtime libraries\n"
xcrun swift-stdlib-tool --copy --platform macosx \
  --destination "$FRAMEWORKS_DIR" \
  --scan-executable "$MACOS_DIR/$EXECUTABLE_NAME" \
  --scan-folder "$BUILD_DIR" >/dev/null

printf "▶︎ Performing ad-hoc codesign\n"
codesign --force --deep --sign - "$APP_DIR"

cat <<EOF > "$CONTENTS_DIR/PkgInfo"
APPL????
EOF

printf "\n✅ App bundle ready: %s\n" "$APP_DIR"
printf "   You can compress and distribute this .app or notarize/sign it with your Developer ID.\n"
