# ClipFlow Release Process

## Quick Start - Build for Personal Use

### Option 1: Local Build (No Signing)
```bash
# Build .app bundle
./Scripts/build-app.sh

# Install on your Mac
cp -R Build/ClipFlow.app /Applications/

# First time: Right-click → Open (bypass Gatekeeper)
```

### Option 2: GitHub Actions Build
1. Go to Actions → Build Release
2. Click "Run workflow"
3. Download artifact
4. Right-click → Open on first launch

---

## Distribution - Signed & Notarized

### Prerequisites

You'll need:
- Apple Developer Account ($99/year)
- Developer ID Application Certificate
- App-Specific Password for notarization

### Setup GitHub Secrets

Add these secrets to your repository (Settings → Secrets → Actions):

| Secret Name | Description | How to Get |
|-------------|-------------|-----------|
| `APPLE_CERTIFICATE_BASE64` | Base64-encoded .p12 certificate | See below ↓ |
| `APPLE_CERTIFICATE_PASSWORD` | Password for .p12 file | Password you set when exporting |
| `APPLE_TEAM_ID` | Your Apple Team ID | developer.apple.com → Membership |
| `APPLE_IDENTITY` | Certificate name | Usually "Developer ID Application: Your Name (TEAM_ID)" |
| `APPLE_ID` | Your Apple ID email | Your iCloud/Apple ID |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password | See below ↓ |

### Get Base64 Certificate

```bash
# Export certificate from Keychain as .p12
# Then convert to base64:
base64 -i YourCertificate.p12 | pbcopy
# Paste into APPLE_CERTIFICATE_BASE64 secret
```

### Get App-Specific Password

1. Go to https://appleid.apple.com
2. Sign in
3. Security → App-Specific Passwords
4. Generate password for "ClipFlow Notarization"
5. Save it to `APPLE_APP_SPECIFIC_PASSWORD` secret

### Create Signed Release

```bash
# Tag and push
git tag v1.0.0-signed
git push origin v1.0.0-signed

# GitHub Actions will:
# 1. Build app bundle
# 2. Code sign with your certificate
# 3. Notarize with Apple
# 4. Create DMG
# 5. Create GitHub Release with signed DMG
```

---

## Testing on Another Mac

### Unsigned Build (Dev/Testing)
1. Build locally: `./Scripts/build-app.sh`
2. Compress: `ditto -c -k Build/ClipFlow.app Build/ClipFlow.zip`
3. Send `ClipFlow.zip` to your other Mac (AirDrop, Dropbox, etc.)
4. Extract and drag to Applications
5. **First time:** Right-click → Open → Open (to bypass Gatekeeper)
6. Subsequent launches: Normal double-click

### Signed Build (Distribution)
1. Download from GitHub Releases
2. Open DMG
3. Drag to Applications
4. Normal double-click - no warnings! ✅

---

## CI/CD Workflows

### `build-release.yml` - Unsigned Build
- Triggers: Manual or on tag `v*.*.*`
- Output: `ClipFlow.dmg` (unsigned)
- Use: Internal testing, development

### `build-signed.yml` - Signed & Notarized
- Triggers: Manual or on tag `v*.*.*-signed`
- Output: `ClipFlow-Signed.dmg` (ready for distribution)
- Use: Public releases, App Store alternative distribution

---

## Troubleshooting

### "App is damaged and can't be opened"
```bash
# Remove quarantine attribute
xattr -cr /Applications/ClipFlow.app
```

### Gatekeeper blocks app
```bash
# Allow app through Gatekeeper
sudo spctl --add /Applications/ClipFlow.app
```

### Reset Gatekeeper for testing
```bash
# Remove from Gatekeeper assessment
sudo spctl --remove /Applications/ClipFlow.app
```

---

## Cost Breakdown

| Option | Cost | Pros | Cons |
|--------|------|------|------|
| **Local build** | Free | Fast, easy | Warning on other Macs |
| **GitHub unsigned** | Free | Automated | Still shows warning |
| **Signed & notarized** | $99/year | No warnings, professional | Apple Developer membership |

---

## Next Steps

1. ✅ Test local build on this Mac
2. ⏳ Test on your other Mac (unsigned)
3. 💰 (Optional) Get Apple Developer membership
4. 🔐 (Optional) Setup signing secrets
5. 🚀 (Optional) Create signed release

Built with ❤️ using [Claude Code](https://claude.ai/code)
