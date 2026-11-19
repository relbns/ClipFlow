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
if codesign -dv "$APP_DIR" 2>&1 | grep -q "Authority=Apple Development"; then
    echo "❌ The app is signed with a development certificate, which is not for distribution."
    echo "   Rebuild with ./build-app.sh --adhoc --universal"
    exit 1
fi
if ! lipo -archs "$APP_DIR/Contents/MacOS/ClipFlow" | grep -q x86_64; then
    echo "❌ The app is Apple Silicon only. Rebuild with ./build-app.sh --adhoc --universal"
    exit 1
fi

VERSION=$(defaults read "$(pwd)/$APP_DIR/Contents/Info.plist" CFBundleShortVersionString)
echo "📦 Packaging ClipFlow $VERSION..."

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"
ditto -c -k --keepParent "$APP_DIR" "$RELEASE_DIR/ClipFlow.zip"

cat > "$RELEASE_DIR/RELEASE_NOTES.md" << EOF
## Install

1. Download \`ClipFlow.zip\`, unzip it and move \`ClipFlow.app\` to your Applications folder.
2. Open it. ClipFlow is not notarized by Apple yet, so the first launch is blocked: open **System Settings → Privacy & Security**, scroll to the message about ClipFlow and click **Open Anyway**.
3. Grant **Accessibility** and **Input Monitoring** when the welcome screen asks. Clipboard history works without them; text expansion and paste-on-pick need both.

Runs on Apple Silicon and Intel Macs with macOS 14 or later. After an update, allow the new version and grant the permissions again.

## What's new

EOF

echo ""
echo "✅ $RELEASE_DIR/ClipFlow.zip"
echo "   Add the changes under \"What's new\" in $RELEASE_DIR/RELEASE_NOTES.md, then:"
echo "   gh release create v$VERSION $RELEASE_DIR/ClipFlow.zip --title \"ClipFlow $VERSION\" --notes-file $RELEASE_DIR/RELEASE_NOTES.md"
