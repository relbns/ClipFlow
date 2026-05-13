#!/bin/bash
set -e

echo "🔧 Fixing ClipFlow.app..."

# Fix Info.plist - replace Xcode variables with actual values
sed -i '' 's/$(EXECUTABLE_NAME)/ClipFlow/g' Build/ClipFlow.app/Contents/Info.plist
sed -i '' 's/$(PRODUCT_NAME)/ClipFlow/g' Build/ClipFlow.app/Contents/Info.plist
sed -i '' 's/$(DEVELOPMENT_LANGUAGE)/en/g' Build/ClipFlow.app/Contents/Info.plist
sed -i '' 's/$(PRODUCT_BUNDLE_PACKAGE_TYPE)/APPL/g' Build/ClipFlow.app/Contents/Info.plist
sed -i '' 's/$(MACOSX_DEPLOYMENT_TARGET)/14.0/g' Build/ClipFlow.app/Contents/Info.plist

echo "✅ Fixed Info.plist"
cat Build/ClipFlow.app/Contents/Info.plist | grep -A 1 "CFBundleExecutable"

# Make sure executable is... executable
chmod +x Build/ClipFlow.app/Contents/MacOS/ClipFlow
echo "✅ Set executable permissions"

# Remove extended attributes (quarantine)
xattr -cr Build/ClipFlow.app 2>/dev/null || true
echo "✅ Removed quarantine attributes"

echo ""
echo "Now run:"
echo "  cp -R Build/ClipFlow.app /Applications/"
echo "  open /Applications/ClipFlow.app"
