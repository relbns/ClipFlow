#!/bin/bash

# Find the running ClipFlow executable
EXEC_PATH=$(ps aux | grep ClipFlow | grep DerivedData | grep -v grep | awk '{print $11}')

if [ -z "$EXEC_PATH" ]; then
    echo "❌ ClipFlow is not running!"
    echo "Please run it from Xcode first (⌘R)"
    exit 1
fi

echo "Found ClipFlow at: $EXEC_PATH"
echo ""
echo "To add to Accessibility:"
echo "1. Open System Settings → Privacy & Security → Accessibility"
echo "2. Click the lock to unlock"
echo "3. Click the + button"
echo "4. Press ⌘⇧G and paste this path:"
echo ""
echo "   $EXEC_PATH"
echo ""
echo "5. Click Open"
echo "6. Make sure the checkbox is ON"
echo "7. Quit ClipFlow (⌘Q) and run again (⌘R)"
echo ""
read -p "Press Enter when done..."
