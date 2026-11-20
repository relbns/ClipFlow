#!/bin/bash
set -e

APP="/Applications/ClipFlow.app"
SUDO=""
if [ -e "$APP" ] && [ ! -w "$APP" ] || [ ! -w /Applications ]; then
    SUDO="sudo"
fi

if ! codesign --verify --deep --strict Build.noindex/ClipFlow.app 2>/dev/null; then
    echo "❌ Build.noindex/ClipFlow.app is incomplete or its signature is invalid. Run ./build-app.sh first"
    exit 1
fi

echo "📦 Installing ClipFlow to /Applications..."

if pgrep -x "ClipFlow" > /dev/null; then
    echo "🛑 Stopping running ClipFlow..."
    pkill -x ClipFlow
    sleep 1
fi

$SUDO rm -rf "$APP"
$SUDO cp -R Build.noindex/ClipFlow.app /Applications/

echo "✅ Installed. Run: open $APP"
echo "   On first run macOS asks for Accessibility and Input Monitoring."
