#!/bin/bash

echo "🔍 ClipFlow App Status Check"
echo "============================"
echo ""

APP_PATH="/Applications/ClipFlow.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ ClipFlow not found in /Applications"
    exit 1
fi

echo "📍 Location: $APP_PATH"
echo ""

# Check bundle version
if [ -f "$APP_PATH/Contents/Info.plist" ]; then
    VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist" 2>/dev/null)
    BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$APP_PATH/Contents/Info.plist" 2>/dev/null)
    BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP_PATH/Contents/Info.plist" 2>/dev/null)

    echo "📦 Version: $VERSION (Build $BUILD)"
    echo "🆔 Bundle ID: $BUNDLE_ID"
    echo ""
fi

# Check code signature
echo "🔐 Code Signature:"
codesign -dv "$APP_PATH" 2>&1 | grep -E "Authority|TeamIdentifier|Identifier" | sed 's/^/   /'
echo ""

# Check if app is running
if pgrep -x "ClipFlow" > /dev/null; then
    echo "✅ ClipFlow is RUNNING"
    PID=$(pgrep -x "ClipFlow")
    echo "   PID: $PID"
    echo "   Memory: $(ps -p $PID -o rss= | awk '{printf "%.1f MB", $1/1024}')"
    echo ""
    echo "📋 To view live logs:"
    echo "   log stream --predicate 'process == \"ClipFlow\"' --level debug"
else
    echo "⏹️  ClipFlow is NOT running"
fi
echo ""

# Check accessibility permission
echo "🔓 Accessibility Permission:"
if sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db \
    "SELECT allowed FROM access WHERE service='kTCCServiceAccessibility' AND client='$BUNDLE_ID';" 2>/dev/null | grep -q 1; then
    echo "   ✅ GRANTED"
else
    echo "   ❌ NOT GRANTED or needs refresh"
    echo "   Reset with: tccutil reset Accessibility io.benesh.clipflow"
fi
echo ""

# Check build timestamp
BUILD_TIME=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$APP_PATH/Contents/MacOS/ClipFlow")
echo "🕐 Last built: $BUILD_TIME"
echo ""

echo "💡 Quick commands:"
echo "   Kill app:    pkill ClipFlow"
echo "   Live logs:   log stream --predicate 'process == \"ClipFlow\"' --level debug"
echo "   Reset TCC:   tccutil reset Accessibility io.benesh.clipflow"
