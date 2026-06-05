#!/bin/bash
set -e

echo "🔨 Building ClipFlow.app..."

# Build release binary
swift build -c release

# Create app bundle structure
APP_DIR="Build/ClipFlow.app"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
mkdir -p "$APP_DIR/Contents/Frameworks"

# Copy binary
cp .build/release/ClipFlow "$APP_DIR/Contents/MacOS/"

# Fix Sparkle framework @rpath reference
echo "🔧 Fixing framework paths..."
install_name_tool -change \
    "@rpath/Sparkle.framework/Versions/B/Sparkle" \
    "@executable_path/../Frameworks/Sparkle.framework/Versions/B/Sparkle" \
    "$APP_DIR/Contents/MacOS/ClipFlow"

# Copy frameworks (Sparkle, etc.)
echo "📦 Copying frameworks..."
if [ -f ".build/release/Sparkle.framework/Sparkle" ]; then
    cp -R .build/release/Sparkle.framework "$APP_DIR/Contents/Frameworks/"
    echo "   ✅ Sparkle.framework"
fi

# Copy any other .framework or .bundle files
find .build/release -name "*.framework" -maxdepth 1 -exec cp -R {} "$APP_DIR/Contents/Frameworks/" \; 2>/dev/null || true
find .build/release -name "*.bundle" -maxdepth 1 -exec cp -R {} "$APP_DIR/Contents/Resources/" \; 2>/dev/null || true

# Copy and fix Info.plist (replace Xcode variables + increment build)
cp Sources/Resources/Info.plist "$APP_DIR/Contents/Info.plist.tmp"

# Get current build number and increment it
CURRENT_BUILD=$(grep -A1 "CFBundleVersion" Sources/Resources/Info.plist | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>/\1/')
NEW_BUILD=$((CURRENT_BUILD + 1))
BUILD_DATE=$(date "+%Y%m%d.%H%M")

sed 's/\$(EXECUTABLE_NAME)/ClipFlow/g' "$APP_DIR/Contents/Info.plist.tmp" | \
sed 's/\$(DEVELOPMENT_LANGUAGE)/en/g' | \
sed "s/<string>\${CURRENT_BUILD}<\/string>/<string>${BUILD_DATE}<\/string>/g" > "$APP_DIR/Contents/Info.plist"
rm "$APP_DIR/Contents/Info.plist.tmp"

echo "📝 Build number: $BUILD_DATE"

# Keep entitlements path for signing (don't copy to app bundle)
ENTITLEMENTS_PATH="Sources/Resources/ClipFlow.entitlements"

# Copy resources if they exist
if [ -d "Sources/Resources/Assets.xcassets" ]; then
    cp -R Sources/Resources/Assets.xcassets "$APP_DIR/Contents/Resources/"
fi

# Copy localizations
if [ -d "Sources/Resources/Localizations" ]; then
    echo "🌍 Copying localizations..."
    cp -R Sources/Resources/Localizations/* "$APP_DIR/Contents/Resources/"
    echo "   ✅ Localizations copied"
fi

# Copy AppIcon.icns if it exists
if [ -f "Sources/Resources/AppIcon.icns" ]; then
    cp Sources/Resources/AppIcon.icns "$APP_DIR/Contents/Resources/"
fi

# Code sign with development certificate
echo "🔐 Code signing..."
CERT_NAME="Apple Development: arielbenesh@gmail.com (5TC494SL83)"

# Sign frameworks first
if [ -d "$APP_DIR/Contents/Frameworks" ]; then
    for framework in "$APP_DIR/Contents/Frameworks"/*.framework; do
        if [ -e "$framework" ]; then
            echo "   Signing $(basename "$framework")..."
            codesign --force --sign "$CERT_NAME" \
                --timestamp \
                --options runtime \
                "$framework/Versions/A" 2>/dev/null || true
        fi
    done
fi

# Sign the main app with entitlements
if [ -f "$ENTITLEMENTS_PATH" ]; then
    codesign --force --sign "$CERT_NAME" \
        --entitlements "$ENTITLEMENTS_PATH" \
        --timestamp \
        --options runtime \
        "$APP_DIR"
else
    codesign --force --sign "$CERT_NAME" \
        --timestamp \
        --options runtime \
        "$APP_DIR"
fi

if [ $? -eq 0 ]; then
    echo "✅ Signed with: $CERT_NAME"
else
    echo "⚠️  Code signing failed - trying ad-hoc..."
    codesign -s - --force --deep "$APP_DIR" 2>/dev/null
fi

echo ""
echo "✅ Built: $APP_DIR"
echo ""
echo "📦 Now install to /Applications:"
echo "   sudo rm -rf /Applications/ClipFlow.app"
echo "   sudo cp -R Build/ClipFlow.app /Applications/"
echo "   sudo chmod -R 755 /Applications/ClipFlow.app"
echo ""
echo "Then:"
echo "1. Open /Applications/ClipFlow.app (NOT from Xcode!)"
echo "2. Grant Accessibility permission (ONLY ONCE!)"
echo "3. Permission will stick because path is stable"
