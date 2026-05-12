#!/bin/bash

echo "Clearing all ClipFlow preferences..."

# Clear app UserDefaults
defaults delete com.singalong.clipflow 2>/dev/null
echo "✅ Cleared app defaults"

# Clear NSStatusBar autosave
defaults delete NSStatusBar 2>/dev/null || true
echo "✅ Cleared status bar defaults"

# Clear any saved window positions
defaults delete com.singalong.clipflow.windows 2>/dev/null || true

# Kill preferences daemon to force reload
killall cfprefsd 2>/dev/null || true
echo "✅ Reloaded preferences daemon"

echo ""
echo "All preferences cleared! Now run the app again."
