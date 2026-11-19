#!/bin/bash
set -e

# Signing modes:
#   --dev (default)  sign with a stable Apple Development identity, so macOS keeps
#                    Accessibility / Input Monitoring trust across rebuilds
#   --adhoc          ad-hoc signature (trust is lost on every rebuild)
#   --notarize       Developer ID + notarization (paid Apple Developer account)
# The dev identity comes from --cert, $CLIPFLOW_SIGN_IDENTITY, or the untracked
# file .signing-identity (one line, the identity name as shown by
# `security find-identity -v -p codesigning`).
SIGNING_MODE="dev"
ENTITLEMENTS_PATH="Sources/Resources/ClipFlow.entitlements"
DEV_CERT="${CLIPFLOW_SIGN_IDENTITY:-}"
if [ -z "$DEV_CERT" ] && [ -f .signing-identity ]; then
    DEV_CERT="$(head -1 .signing-identity)"
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --dev)
            SIGNING_MODE="dev"
            shift
            ;;
        --adhoc|--release)
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
        --sandbox)
            ENTITLEMENTS_PATH="Sources/Resources/ClipFlow-Sandbox.entitlements"
            shift
            ;;
        *)
            echo "Usage: $0 [--dev|--adhoc|--notarize] [--sandbox] [--cert \"Certificate Name\"]"
            exit 1
            ;;
    esac
done

if [ "$SIGNING_MODE" = "dev" ]; then
    if [ -z "$DEV_CERT" ]; then
        echo "❌ No signing identity. Set CLIPFLOW_SIGN_IDENTITY, pass --cert, or write it to .signing-identity"
        echo "   Available identities:"
        security find-identity -v -p codesigning | sed 's/^/   /'
        echo "   Or build with --adhoc (macOS will forget the app's permissions on every rebuild)."
        exit 1
    fi
    if ! security find-identity -v -p codesigning | grep -qF "\"$DEV_CERT\""; then
        echo "❌ Signing identity not found in Keychain: $DEV_CERT"
        exit 1
    fi
fi

echo "🔨 Building ClipFlow.app..."
echo "📝 Signing mode: $SIGNING_MODE"
echo ""

# Build release binary
swift build -c release

# Create app bundle structure from scratch so removed files never linger
APP_DIR="Build.noindex/ClipFlow.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
mkdir -p "$APP_DIR/Contents/Frameworks"

# Copy binary
cp .build/release/ClipFlow "$APP_DIR/Contents/MacOS/"

# Copy any .framework or .bundle files produced by dependencies
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

echo "🔏 Entitlements: $ENTITLEMENTS_PATH"

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
                        --options runtime \
                        "$framework"
                fi
            done
        fi

        # Sign the main app with entitlements
        if [ -f "$ENTITLEMENTS_PATH" ]; then
            codesign --force --sign "$DEV_CERT" \
                --entitlements "$ENTITLEMENTS_PATH" \
                --options runtime \
                "$APP_DIR"
        else
            codesign --force --sign "$DEV_CERT" \
                --options runtime \
                "$APP_DIR"
        fi
        echo "✅ Signed with: $DEV_CERT"
        ;;

    adhoc)
        echo "   Mode: Ad-hoc"
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
        ditto -c -k --keepParent "$APP_DIR" "Build.noindex/ClipFlow.zip"

        echo "   Uploading to Apple (this may take a few minutes)..."
        xcrun notarytool submit "Build.noindex/ClipFlow.zip" \
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

echo "📦 To install locally, run: ./install-app.sh"
