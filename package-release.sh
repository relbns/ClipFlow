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

# The installer: a disk image that opens to ClipFlow, an arrow and the Applications folder
VOLUME="ClipFlow"
STAGING="$RELEASE_DIR/dmg-staging"
WRITABLE="$RELEASE_DIR/ClipFlow-rw.dmg"
# Finder names a disk after its mount folder, which the layout script below refers to
MOUNT="$(pwd)/$RELEASE_DIR/$VOLUME"
if [ -d "/Volumes/$VOLUME" ]; then
    echo "❌ A volume named $VOLUME is mounted. Eject it first."
    exit 1
fi
# A mount left by an interrupted run would otherwise be emptied by the rm below
if mount | grep -q " on $MOUNT "; then
    hdiutil detach -force -quiet "$MOUNT"
fi
detach_image() {
    for _ in 1 2 3 4 5; do
        hdiutil detach -quiet "$MOUNT" 2>/dev/null && return 0
        sleep 1
    done
    hdiutil detach -force -quiet "$MOUNT"
}
trap 'mount | grep -q " on $MOUNT " && hdiutil detach -force -quiet "$MOUNT"' EXIT

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"
mkdir -p "$STAGING/.background"
ditto --norsrc --noextattr --noacl "$APP_DIR" "$STAGING/ClipFlow.app"
ln -s /Applications "$STAGING/Applications"
tiffutil -cathidpicheck Packaging/dmg-background.png Packaging/dmg-background@2x.png -out "$STAGING/.background/background.tiff" >/dev/null
hdiutil create -quiet -srcfolder "$STAGING" -volname "$VOLUME" -fs HFS+ -format UDRW -ov "$WRITABLE"
mkdir -p "$MOUNT"
hdiutil attach -quiet -readwrite -noverify -noautoopen -mountpoint "$MOUNT" "$WRITABLE"
# A Finder automation prompt left unanswered would otherwise hang the script; give up after a minute
if ! perl -e 'alarm shift; exec @ARGV' 60 osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOLUME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {200, 140, 860, 540}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set text size of viewOptions to 13
        set background picture of viewOptions to file ".background:background.tiff"
        set extension hidden of item "ClipFlow.app" to true
        set position of item "ClipFlow.app" of container window to {165, 170}
        set position of item "Applications" of container window to {495, 170}
        update without registering applications
        delay 1
        close
        -- Finder saves the window size only once it is reopened and closed again
        open
        set bounds of container window to {200, 140, 860, 540}
        delay 2
        close
    end tell
end tell
APPLESCRIPT
then
    echo "⚠️  Finder did not lay out the installer window; the disk image still holds ClipFlow and Applications."
fi
# Wait until Finder has written the layout and left it alone for two seconds
stable=0
previous=""
for _ in $(seq 1 15); do
    current=$(stat -f "%m %z" "$MOUNT/.DS_Store" 2>/dev/null || echo "missing")
    if [ "$current" != "missing" ] && [ "$current" = "$previous" ]; then
        stable=$((stable + 1))
        [ "$stable" -ge 2 ] && break
    else
        stable=0
    fi
    previous="$current"
    sleep 1
done
sync
detach_image
hdiutil convert -quiet "$WRITABLE" -format UDZO -imagekey zlib-level=9 -o "$RELEASE_DIR/ClipFlow.dmg"
rm -rf "$WRITABLE" "$STAGING" "$MOUNT"

cat > "$RELEASE_DIR/RELEASE_NOTES.md" << EOF
## Install

1. Download \`ClipFlow.dmg\` and open it, then drag **ClipFlow** onto **Applications**.
2. Open ClipFlow from Applications. ClipFlow is not notarized by Apple yet, so macOS blocks the first launch. Then open **System Settings → Privacy & Security**, scroll to the message about ClipFlow, click **Open Anyway** and confirm with your password.
3. Grant **Accessibility** and **Input Monitoring** when the welcome screen asks. Clipboard history works without them. Text expansion needs both, and paste-on-pick needs Accessibility.

Runs on Apple Silicon and Intel Macs with macOS 14 or later. After an update, allow the new version the same way, then remove ClipFlow from both permission lists with **−** and grant them again.

## What's new

EOF

echo ""
echo "✅ $RELEASE_DIR/ClipFlow.dmg"
echo "   Add the changes under \"What's new\" in $RELEASE_DIR/RELEASE_NOTES.md, then:"
echo "   gh release create v$VERSION $RELEASE_DIR/ClipFlow.dmg --title \"ClipFlow $VERSION\" --notes-file $RELEASE_DIR/RELEASE_NOTES.md"
SHA256=$(shasum -a 256 "$RELEASE_DIR/ClipFlow.dmg" | awk '{print $1}')
[ -n "$SHA256" ] || { echo "❌ Could not compute the sha256 of $RELEASE_DIR/ClipFlow.dmg"; exit 1; }
echo ""
echo "   Then update the Homebrew cask (relbns/homebrew-tap, Casks/clipflow.rb) to:"
echo "     version \"$VERSION\""
echo "     sha256 \"$SHA256\""
echo "   Check the sha256 against the published download before merging the cask change."
