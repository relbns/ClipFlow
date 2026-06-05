#!/bin/bash
set -e

# Parse arguments
SIGNING_MODE="adhoc"  # Default: ad-hoc signing for distribution
DEV_CERT="Apple Development: arielbenesh@gmail.com (5TC494SL83)"

while [[ $# -gt 0 ]]; do
    case $1 in
        --dev)
            SIGNING_MODE="dev"
            shift
            ;;
        --release)
            SIGNING_MODE="adhoc"
            shift
            ;;
        --notarize)
            SIGNING_MODE="notarize"
            shift
            ;;
        --cert)
            DEV_CERT="$2"
            shift 2
            ;;
        *)
            echo "Usage: $0 [--dev|--release|--notarize] [--cert \"Certificate Name\"]"
            echo ""
            echo "Modes:"
            echo "  --dev        Sign with development certificate (for local testing)"
            echo "  --release    Ad-hoc signing (default, for GitHub distribution)"
            echo "  --notarize   Sign with Developer ID + notarize (requires Apple Developer account)"
            echo "  --cert       Specify custom certificate name"
            exit 1
            ;;
    esac
done

echo "🔨 Building ClipFlow.app..."
echo "📝 Signing mode: $SIGNING_MODE"
echo ""

# Build release binary
swift build -c release

# Create app bundle structure
APP_DIR="Build/ClipFlow.app"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
mkdir -p "$APP_DIR/Contents/Frameworks"

# Copy binary
cp .build/release/ClipFlow "$APP_DIR/Contents/MacOS/"

# Fix Sparkle framework @rpath reference
echo "🔧 Fixing framework paths..."
install_name_tool -change \
    "@rpath/Sparkle.framework/Versions/B/Sparkle" \
    "@executable_path/../Frameworks/Sparkle.framework/Versions/B/Sparkle" \
    "$APP_DIR/Contents/MacOS/ClipFlow"

# Copy frameworks (Sparkle, etc.)
echo "📦 Copying frameworks..."
if [ -f ".build/release/Sparkle.framework/Sparkle" ]; then
    cp -R .build/release/Sparkle.framework "$APP_DIR/Contents/Frameworks/"
    echo "   ✅ Sparkle.framework"
fi

# Copy any other .framework or .bundle files
find .build/release -name "*.framework" -maxdepth 1 -exec cp -R {} "$APP_DIR/Contents/Frameworks/" \; 2>/dev/null || true
find .build/release -name "*.bundle" -maxdepth 1 -exec cp -R {} "$APP_DIR/Contents/Resources/" \; 2>/dev/null || true

# Copy and fix Info.plist (replace Xcode variables + increment build)
cp Sources/Resources/Info.plist "$APP_DIR/Contents/Info.plist.tmp"

# Get current build number and increment it
CURRENT_BUILD=$(grep -A1 "CFBundleVersion" Sources/Resources/Info.plist | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>/\1/')
NEW_BUILD=$((CURRENT_BUILD + 1))
BUILD_DATE=$(date "+%Y%m%d.%H%M")

sed 's/\$(EXECUTABLE_NAME)/ClipFlow/g' "$APP_DIR/Contents/Info.plist.tmp" | \
sed 's/\$(DEVELOPMENT_LANGUAGE)/en/g' | \
sed "s/<string>\${CURRENT_BUILD}<\/string>/<string>${BUILD_DATE}<\/string>/g" > "$APP_DIR/Contents/Info.plist"
rm "$APP_DIR/Contents/Info.plist.tmp"

echo "📝 Build number: $BUILD_DATE"

# Keep entitlements path for signing (don't copy to app bundle)
ENTITLEMENTS_PATH="Sources/Resources/ClipFlow.entitlements"

# Copy resources if they exist
if [ -d "Sources/Resources/Assets.xcassets" ]; then
    cp -R Sources/Resources/Assets.xcassets "$APP_DIR/Contents/Resources/"
fi

# Copy localizations
if [ -d "Sources/Resources/Localizations" ]; then
    echo "🌍 Copying localizations..."
    cp -R Sources/Resources/Localizations/* "$APP_DIR/Contents/Resources/"
    echo "   ✅ Localizations copied"
fi

# Copy AppIcon.icns if it exists
if [ -f "Sources/Resources/AppIcon.icns" ]; then
    cp Sources/Resources/AppIcon.icns "$APP_DIR/Contents/Resources/"
fi

# Code signing based on mode
echo "🔐 Code signing..."

case $SIGNING_MODE in
    dev)
        echo "   Mode: Development certificate"
        # Sign frameworks first
        if [ -d "$APP_DIR/Contents/Frameworks" ]; then
            for framework in "$APP_DIR/Contents/Frameworks"/*.framework; do
                if [ -e "$framework" ]; then
                    echo "   Signing $(basename "$framework")..."
                    codesign --force --sign "$DEV_CERT" \
                        --timestamp \
                        --options runtime \
                        "$framework/Versions/A" 2>/dev/null || true
                fi
            done
        fi

        # Sign the main app with entitlements
        if [ -f "$ENTITLEMENTS_PATH" ]; then
            codesign --force --sign "$DEV_CERT" \
                --entitlements "$ENTITLEMENTS_PATH" \
                --timestamp \
                --options runtime \
                "$APP_DIR"
        else
            codesign --force --sign "$DEV_CERT" \
                --timestamp \
                --options runtime \
                "$APP_DIR"
        fi

        if [ $? -eq 0 ]; then
            echo "✅ Signed with: $DEV_CERT"
        else
            echo "❌ Signing failed - check certificate name"
            exit 1
        fi
        ;;

    adhoc)
        echo "   Mode: Ad-hoc (unsigned, for distribution)"
        # Ad-hoc signing - no certificate needed
        codesign --force --deep --sign - "$APP_DIR" 2>/dev/null
        echo "✅ Ad-hoc signed (users will need to allow in System Settings)"
        ;;

    notarize)
        echo "   Mode: Developer ID + Notarization"
        echo "⚠️  Notarization requires:"
        echo "   1. Apple Developer account ($99/year)"
        echo "   2. Developer ID Application certificate in Keychain"
        echo "   3. App-specific password stored in Keychain"
        echo ""
        read -p "Continue? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi

        # Find Developer ID certificate
        DEV_ID_CERT=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | grep -o '".*"' | sed 's/"//g')

        if [ -z "$DEV_ID_CERT" ]; then
            echo "❌ No Developer ID Application certificate found in Keychain"
            echo "   Install it from developer.apple.com/account"
            exit 1
        fi

        echo "   Using certificate: $DEV_ID_CERT"

        # Sign frameworks first
        if [ -d "$APP_DIR/Contents/Frameworks" ]; then
            for framework in "$APP_DIR/Contents/Frameworks"/*.framework; do
                if [ -e "$framework" ]; then
                    echo "   Signing $(basename "$framework")..."
                    codesign --force --sign "$DEV_ID_CERT" \
                        --timestamp \
                        --options runtime \
                        "$framework/Versions/A"
                fi
            done
        fi

        # Sign the main app
        if [ -f "$ENTITLEMENTS_PATH" ]; then
            codesign --force --sign "$DEV_ID_CERT" \
                --entitlements "$ENTITLEMENTS_PATH" \
                --timestamp \
                --options runtime \
                "$APP_DIR"
        else
            codesign --force --sign "$DEV_ID_CERT" \
                --timestamp \
                --options runtime \
                "$APP_DIR"
        fi

        echo "✅ Signed with Developer ID"

        # Notarize
        echo "📤 Submitting for notarization..."
        echo "   Creating ZIP..."
        ditto -c -k --keepParent "$APP_DIR" "Build/ClipFlow.zip"

        echo "   Uploading to Apple (this may take a few minutes)..."
        xcrun notarytool submit "Build/ClipFlow.zip" \
            --keychain-profile "notarytool" \
            --wait

        if [ $? -eq 0 ]; then
            echo "✅ Notarization successful!"
            xcrun stapler staple "$APP_DIR"
            echo "✅ Notarization ticket stapled to app"
        else
            echo "❌ Notarization failed"
            echo "   Check logs with: xcrun notarytool log --keychain-profile notarytool <submission-id>"
            exit 1
        fi
        ;;
esac

echo ""
echo "✅ Built: $APP_DIR"
echo ""

if [ "$SIGNING_MODE" = "adhoc" ]; then
    echo "📦 For GitHub distribution, run: ./package-release.sh"
    echo ""
elif [ "$SIGNING_MODE" = "dev" ]; then
    echo "📦 For local installation, run: ./install-app.sh"
    echo ""
fi
