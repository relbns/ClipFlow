#!/bin/bash
set -e

APP="/Applications/ClipFlow.app"
SUDO=""
if [ -e "$APP" ] && [ ! -w "$APP" ] || [ ! -w /Applications ]; then
    SUDO="sudo"
fi

echo "📦 Installing ClipFlow to /Applications..."

if pgrep -x "ClipFlow" > /dev/null; then
    echo "🛑 Stopping running ClipFlow..."
    pkill -x ClipFlow
    sleep 1
fi

$SUDO rm -rf "$APP"
$SUDO cp -R Build/ClipFlow.app /Applications/

echo "✅ Installed. Run: open $APP"
echo "   On first run macOS asks for Accessibility and Input Monitoring."
