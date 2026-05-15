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

# Copy and fix Info.plist (replace Xcode variables)
cp Sources/Resources/Info.plist "$APP_DIR/Contents/Info.plist.tmp"
sed 's/\$(EXECUTABLE_NAME)/ClipFlow/g' "$APP_DIR/Contents/Info.plist.tmp" | \
sed 's/\$(DEVELOPMENT_LANGUAGE)/en/g' | \
sed 's/\$(PRODUCT_BUNDLE_IDENTIFIER)/com.singalong.clipflow/g' > "$APP_DIR/Contents/Info.plist"
rm "$APP_DIR/Contents/Info.plist.tmp"

# Copy entitlements
if [ -f "Sources/Resources/ClipFlow.entitlements" ]; then
    cp Sources/Resources/ClipFlow.entitlements "$APP_DIR/Contents/"
fi

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

# Try to code sign (optional, won't fail if no identity)
echo "🔐 Attempting to code sign..."
if codesign -s - --force --deep "$APP_DIR" 2>/dev/null; then
    echo "✅ Code signed (ad-hoc)"
else
    echo "⚠️  Code sign skipped (not critical)"
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
