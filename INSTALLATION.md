# ClipFlow Installation Guide

ClipFlow is a free, open-source clipboard manager and text expander for macOS.

## Download

### Pre-built Release (Easiest)
Download the latest version from [GitHub Releases](https://github.com/relbns/ClipFlow/releases)

### Build from Source (Developers)
See [Building from Source](#building-from-source) below

---

## Installation Steps

### 1. Download
- Download `ClipFlow.dmg` from Releases and open it
- Drag ClipFlow onto Applications in the window that opens

### 2. Move to Applications
```bash
# Option A: Drag & Drop
# Drag ClipFlow.app to /Applications in Finder

# Option B: Terminal
cp -R ClipFlow.app /Applications/
```

### 3. First Launch (Important!)

⚠️ **ClipFlow is not notarized by Apple** (we're open source and free). You'll see a security warning.

**Method 1: Right-Click Open (Recommended)**
1. Open Finder → Applications
2. Find ClipFlow.app
3. **Right-click** → **Open** (not double-click!)
4. Click **Open** in the dialog

**Method 2: Remove Quarantine (Terminal)**
```bash
xattr -cr /Applications/ClipFlow.app
open /Applications/ClipFlow.app
```

### 4. Grant Accessibility Permission

ClipFlow needs Accessibility permission for:
- Monitoring clipboard changes
- Text expansion (backspace simulation)
- Pasting content

**Steps:**
1. System Settings → Privacy & Security → Accessibility
2. Click the 🔒 lock icon to unlock
3. Find ClipFlow in the list
4. Toggle it **ON**
5. If not in the list: click **+** and add ClipFlow

**Verify it works:**
- ClipFlow icon should appear in your menu bar
- Copy some text → click the menu bar icon → see your history

---

## Troubleshooting

### "ClipFlow cannot be opened because the developer cannot be verified"

**Solution:** Use Right-Click → Open (see step 3 above)

### App opens but doesn't capture clipboard

**Cause:** Accessibility permission not granted

**Solution:**
1. Check System Settings → Privacy & Security → Accessibility
2. Make sure ClipFlow is **enabled**
3. If it's already there, try:
   ```bash
   tccutil reset Accessibility io.benesh.clipflow
   # Then re-grant permission
   ```

### Text expansion doesn't work

**Checklist:**
1. ✅ Accessibility permission granted?
2. ✅ Text expansion enabled in ClipFlow Settings?
3. ✅ Snippet has correct abbreviation?
4. ✅ Trigger character configured (space, tab, etc.)?

**Debug:**
```bash
# View live logs
log stream --predicate 'process == "ClipFlow"' --level debug
```

### App crashes on launch

**Solution:**
```bash
# Remove preferences
rm -rf ~/Library/Application\ Support/ClipFlow
rm ~/Library/Preferences/io.benesh.clipflow.plist

# Restart
open /Applications/ClipFlow.app
```

### App won't quit

```bash
pkill ClipFlow
# or
killall ClipFlow
```

---

## Building from Source

### Requirements
- macOS 14.0 Sonoma or later
- Xcode 15.0+ or Swift 6.0+ command line tools
- Git

### Quick Build
```bash
# Clone repository
git clone https://github.com/relbns/ClipFlow.git
cd ClipFlow

# Build for distribution (ad-hoc signing)
./build-app.sh --release

# Install to /Applications
./install-app.sh
```

### Build Modes

#### 1. Development Build (for yourself)
```bash
# Uses your Apple Development certificate
./build-app.sh --dev
./install-app.sh
```

#### 2. Distribution Build (for GitHub releases)
```bash
# Ad-hoc signing (no certificate needed), Apple Silicon and Intel
./build-app.sh --adhoc --universal

# Create release package
./package-release.sh
```

#### 3. Notarized Build (requires paid Apple Developer account)
```bash
# Requires Developer ID certificate + notarytool setup
./build-app.sh --notarize
./package-release.sh
```

### Build Scripts

- **build-app.sh** - Compiles and signs the app
- **install-app.sh** - Installs to /Applications
- **check-app.sh** - Verifies installation and permissions
- **package-release.sh** - Creates the installer disk image (DMG) for distribution

---

## Uninstallation

```bash
# Stop the app
pkill ClipFlow

# Remove app
rm -rf /Applications/ClipFlow.app

# Remove user data (optional)
rm -rf ~/Library/Application\ Support/ClipFlow
rm ~/Library/Preferences/io.benesh.clipflow.plist

# Reset Accessibility permission (optional)
tccutil reset Accessibility io.benesh.clipflow
```

---

## Why isn't ClipFlow notarized?

**Notarization requires:**
- Apple Developer account ($99/year)
- Developer ID certificate
- Apple's approval process

**We chose to stay free and open:**
- No subscription fees
- No Apple dependency
- Faster updates
- Full source code access

The tradeoff: You'll see a security warning on first launch. This is normal for open-source Mac apps distributed outside the App Store.

**Is it safe?**
- Yes! ClipFlow is 100% open source
- You can review every line of code on GitHub
- Build it yourself if you prefer
- No network access, no telemetry, no tracking

---

## Need Help?

- 🐛 **Bug Reports:** [GitHub Issues](https://github.com/relbns/ClipFlow/issues)
- 💬 **Questions:** [GitHub Discussions](https://github.com/relbns/ClipFlow/discussions)
- 📖 **Documentation:** [README.md](README.md)

---

**Enjoy ClipFlow!** ❤️
