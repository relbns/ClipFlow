#!/bin/bash

# Build ClipFlow.app bundle from swift build output
# This creates a proper .app bundle with icon and Info.plist

set -e

echo "🔨 Building ClipFlow..."
swift build -c release

BUILD_DIR=".build/arm64-apple-macosx/release"
APP_NAME="ClipFlow"
APP_BUNDLE="Build/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
FRAMEWORKS_DIR="${CONTENTS_DIR}/Frameworks"

echo "📦 Creating app bundle structure..."
rm -rf "Build/${APP_NAME}.app"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
mkdir -p "$FRAMEWORKS_DIR"

echo "📋 Copying executable..."
cp "${BUILD_DIR}/${APP_NAME}" "$MACOS_DIR/"

echo "🎨 Copying resources..."
cp -R "${BUILD_DIR}/${APP_NAME}_${APP_NAME}.bundle" "$RESOURCES_DIR/" || true

echo "📚 Copying frameworks..."
if [ -d "${BUILD_DIR}/Sparkle.framework" ]; then
    cp -R "${BUILD_DIR}/Sparkle.framework" "$FRAMEWORKS_DIR/"
fi
if [ -d "${BUILD_DIR}/KeyboardShortcuts.framework" ]; then
    cp -R "${BUILD_DIR}/KeyboardShortcuts.framework" "$FRAMEWORKS_DIR/"
fi

echo "🔧 Fixing rpath..."
install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/$APP_NAME" 2>/dev/null || true

# Create App Icon from PNGs
echo "🖼  Creating app icon..."
ICONSET_DIR="/tmp/${APP_NAME}.iconset"
mkdir -p "$ICONSET_DIR"

# Copy icon files from Assets
ICON_SOURCE="Sources/Resources/Assets.xcassets/AppIcon.appiconset"
cp "${ICON_SOURCE}/icon_16x16.png" "${ICONSET_DIR}/icon_16x16.png"
cp "${ICON_SOURCE}/icon_16x16@2x.png" "${ICONSET_DIR}/icon_16x16@2x.png"
cp "${ICON_SOURCE}/icon_32x32.png" "${ICONSET_DIR}/icon_32x32.png"
cp "${ICON_SOURCE}/icon_32x32@2x.png" "${ICONSET_DIR}/icon_32x32@2x.png"
cp "${ICON_SOURCE}/icon_128x128.png" "${ICONSET_DIR}/icon_128x128.png"
cp "${ICON_SOURCE}/icon_128x128@2x.png" "${ICONSET_DIR}/icon_128x128@2x.png"
cp "${ICON_SOURCE}/icon_256x256.png" "${ICONSET_DIR}/icon_256x256.png"
cp "${ICON_SOURCE}/icon_256x256@2x.png" "${ICONSET_DIR}/icon_256x256@2x.png"
cp "${ICON_SOURCE}/icon_512x512.png" "${ICONSET_DIR}/icon_512x512.png"
cp "${ICON_SOURCE}/icon_512x512@2x.png" "${ICONSET_DIR}/icon_512x512@2x.png"

# Create .icns file
iconutil -c icns "$ICONSET_DIR" -o "${RESOURCES_DIR}/${APP_NAME}.icns"
rm -rf "$ICONSET_DIR"

echo "📝 Creating Info.plist..."
cat > "${CONTENTS_DIR}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>co.singalong.clipflow</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 ClipFlow. All rights reserved.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "✅ App bundle created at: ${APP_BUNDLE}"
echo ""
echo "To run: open ${APP_BUNDLE}"
echo "To install: cp -R ${APP_BUNDLE} /Applications/"
