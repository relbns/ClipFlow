#!/bin/bash
set -e

echo "📦 Installing ClipFlow to /Applications..."
echo ""

# Kill running app
if pgrep -x "ClipFlow" > /dev/null; then
    echo "🛑 Stopping running ClipFlow..."
    pkill ClipFlow
    sleep 1
fi

# Remove old version
if [ -d "/Applications/ClipFlow.app" ]; then
    echo "🗑️  Removing old version..."
    sudo rm -rf /Applications/ClipFlow.app
fi

# Copy new version
echo "📥 Copying new version..."
sudo cp -R Build/ClipFlow.app /Applications/
sudo chmod -R 755 /Applications/ClipFlow.app

echo ""
echo "✅ Installation complete!"
echo ""
echo "🚀 Now run: open /Applications/ClipFlow.app"
echo ""
echo "If you need to grant Accessibility permission again:"
echo "   System Settings → Privacy & Security → Accessibility → Add ClipFlow"
