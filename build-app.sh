#!/bin/bash
set -e

echo "🔨 Building ClipFlow.app..."

# Build release binary
swift build -c release

# Create app bundle structure  
APP_DIR="Build/ClipFlow.app"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy binary
cp .build/release/ClipFlow "$APP_DIR/Contents/MacOS/"

# Copy Info.plist
cp Sources/Resources/Info.plist "$APP_DIR/Contents/"

# Copy resources if they exist
if [ -d "Sources/Resources/Assets.xcassets" ]; then
    cp -R Sources/Resources/Assets.xcassets "$APP_DIR/Contents/Resources/"
fi

echo "✅ Built: $APP_DIR"
echo ""
echo "Now:"
echo "1. Drag Build/ClipFlow.app to /Applications"
echo "2. Run from /Applications"
echo "3. Grant Accessibility permission"
