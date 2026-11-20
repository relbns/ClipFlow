#!/bin/bash
set -e

# Packages the downloadable release. Build it first with:
#   ./build-app.sh --adhoc --universal
APP_DIR="Build.noindex/ClipFlow.app"
RELEASE_DIR="Build.noindex/Release"

if [ ! -d "$APP_DIR" ]; then
    echo "❌ $APP_DIR not found. Run ./build-app.sh --adhoc --universal first"
    exit 1
fi
if ! codesign -dv "$APP_DIR" 2>&1 | grep -q "^Signature=adhoc"; then
    echo "❌ The app is not ad-hoc signed. A development signature carries your name and Team ID."
    echo "   Rebuild with ./build-app.sh --adhoc --universal"
    exit 1
fi
codesign --verify --deep --strict "$APP_DIR"
# The single-arch build finds its resource bundles only on the Mac that built it
if ! lipo -archs "$APP_DIR/Contents/MacOS/ClipFlow" | grep -q x86_64; then
    echo "❌ The app is Apple Silicon only. Rebuild with ./build-app.sh --adhoc --universal"
    exit 1
fi

VERSION=$(defaults read "$(pwd)/$APP_DIR/Contents/Info.plist" CFBundleShortVersionString)
if gh release view "v$VERSION" >/dev/null 2>&1; then
    echo "❌ Release v$VERSION already exists. Raise CFBundleShortVersionString in Sources/Resources/Info.plist and rebuild."
    exit 1
fi
echo "📦 Packaging ClipFlow $VERSION..."

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"
# Without extended attributes, so the signature survives any unzip tool
ditto -c -k --keepParent --norsrc --noextattr --noacl "$APP_DIR" "$RELEASE_DIR/ClipFlow.zip"

cat > "$RELEASE_DIR/RELEASE_NOTES.md" << EOF
## Install

1. Download \`ClipFlow.zip\`, unzip it and move \`ClipFlow.app\` to your Applications folder.
2. Open it. ClipFlow is not notarized by Apple yet, so macOS blocks the first launch. Then open **System Settings → Privacy & Security**, scroll to the message about ClipFlow, click **Open Anyway** and confirm with your password.
3. Grant **Accessibility** and **Input Monitoring** when the welcome screen asks. Clipboard history works without them. Text expansion needs both, and paste-on-pick needs Accessibility.

Runs on Apple Silicon and Intel Macs with macOS 14 or later. After an update, allow the new version the same way, then remove ClipFlow from both permission lists with **−** and grant them again.

## What's new

EOF

echo ""
echo "✅ $RELEASE_DIR/ClipFlow.zip"
echo "   Add the changes under \"What's new\" in $RELEASE_DIR/RELEASE_NOTES.md, then:"
echo "   gh release create v$VERSION $RELEASE_DIR/ClipFlow.zip --title \"ClipFlow $VERSION\" --notes-file $RELEASE_DIR/RELEASE_NOTES.md"
