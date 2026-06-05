#!/bin/bash
set -e

APP_DIR="Build/ClipFlow.app"
RELEASE_DIR="Build/Release"
VERSION=$(defaults read "$(pwd)/$APP_DIR/Contents/Info.plist" CFBundleShortVersionString)
BUILD=$(defaults read "$(pwd)/$APP_DIR/Contents/Info.plist" CFBundleVersion)

echo "📦 Packaging ClipFlow v$VERSION (Build $BUILD) for release..."
echo ""

# Check if app exists
if [ ! -d "$APP_DIR" ]; then
    echo "❌ ClipFlow.app not found. Run ./build-app.sh first"
    exit 1
fi

# Create release directory
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

# Copy app
cp -R "$APP_DIR" "$RELEASE_DIR/"

# Create installation instructions
cat > "$RELEASE_DIR/INSTALL.txt" << 'EOF'
ClipFlow Installation Instructions
===================================

ClipFlow is open source and distributed without Apple notarization.
This means macOS will show a security warning on first launch.

Installation Steps:
-------------------

1. Move ClipFlow.app to /Applications:
   - Drag ClipFlow.app to your Applications folder
   - Or via Terminal:
     cp -R ClipFlow.app /Applications/

2. First Launch - IMPORTANT:
   - Do NOT double-click ClipFlow.app
   - Instead: Right-click → Open
   - Click "Open" in the security dialog
   - OR remove quarantine attribute:
     xattr -cr /Applications/ClipFlow.app
     open /Applications/ClipFlow.app

3. Grant Accessibility Permission:
   - ClipFlow needs this for clipboard monitoring and text expansion
   - System Settings → Privacy & Security → Accessibility
   - Click the lock to unlock
   - Add ClipFlow and enable it

4. Done!
   - ClipFlow will appear in your menu bar
   - Set up your hotkeys in Settings

Troubleshooting:
----------------

If the app won't open:
  xattr -cr /Applications/ClipFlow.app

If text expansion doesn't work:
  - Check Accessibility permission is granted
  - Enable text expansion in ClipFlow Settings

For more help, visit:
https://github.com/relbns/ClipFlow/issues

---
ClipFlow is free and open source (MIT License)
Built with ❤️ for macOS
EOF

# Create README for GitHub release
cat > "$RELEASE_DIR/RELEASE_NOTES.md" << EOF
# ClipFlow v$VERSION

## Installation

### Option 1: Download & Install (Recommended)
1. Download \`ClipFlow.zip\`
2. Unzip and read \`INSTALL.txt\`
3. Move \`ClipFlow.app\` to \`/Applications\`
4. **Right-click → Open** (first time only)
5. Grant Accessibility permission

### Option 2: Build from Source
\`\`\`bash
git clone https://github.com/relbns/ClipFlow.git
cd ClipFlow
./build-app.sh --release
./install-app.sh
\`\`\`

## What's New in v$VERSION

[Add your release notes here]

## Requirements
- macOS 14.0 Sonoma or later
- Accessibility permission (for clipboard & text expansion)

## Support
- Issues: https://github.com/relbns/ClipFlow/issues
- Discussions: https://github.com/relbns/ClipFlow/discussions

---
**Note**: ClipFlow is not notarized by Apple. This is intentional - we're open source and free.
You'll need to allow the app in System Settings on first launch.
EOF

# Create ZIP
echo "🗜️  Creating ZIP archive..."
cd "$RELEASE_DIR"
zip -r "../ClipFlow-v$VERSION.zip" . -x "*.DS_Store"
cd - > /dev/null

echo ""
echo "✅ Release package created:"
echo "   📦 Build/ClipFlow-v$VERSION.zip"
echo "   📝 Build/Release/INSTALL.txt"
echo "   📄 Build/Release/RELEASE_NOTES.md"
echo ""
echo "Next steps:"
echo "1. Test the ZIP on a clean Mac"
echo "2. Edit Build/Release/RELEASE_NOTES.md with changelog"
echo "3. Create GitHub release:"
echo "   gh release create v$VERSION Build/ClipFlow-v$VERSION.zip"
echo "   --title \"ClipFlow v$VERSION\""
echo "   --notes-file Build/Release/RELEASE_NOTES.md"
echo ""
