# ClipFlow

> Modern Clipboard Manager + Text Expander for macOS

ClipFlow combines powerful clipboard history management with real-time text expansion, supporting variables, Hebrew RTL, and cloud sync.

[![CI](https://github.com/relbns/ClipFlow/actions/workflows/ci.yml/badge.svg)](https://github.com/relbns/ClipFlow/actions)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue.svg)](https://www.apple.com/macos/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## ✨ Features

### 📋 Clipboard Manager
- **Two UI Modes**:
  - **Simple Mode**: Flycut-style flat list with keyboard shortcuts (1-9, 0)
  - **Organized Mode**: Grouped by type (Recent, Images, URLs, Text)
- **Rich Content Support**: Text, images, URLs, hex colors
- **Image Thumbnails**: Preview images directly in menu (24x24 / 32x32)
- **Color Swatches**: Visual preview for hex color codes (#FF5733)
- **RTL Support**: Full Hebrew right-to-left text support
- **Search**: Instant filter across all clipboard items

### ⚡ Text Expansion
- **Real-time Expansion**: Type abbreviations, get full text instantly
- **Trigger Options**: Space, delimiter, any character, tab, enter
- **Dynamic Variables**:
  - `{date}`, `{date:yyyy-MM-dd}`, `{date:hebrew}`
  - `{time}`, `{time:HH:mm}`
  - `{clipboard}` - Current clipboard content
  - `{cursor}` - Cursor position after expansion
  - `{year}`, `{month}`, `{day}`
- **Custom Variables**: `{name:prompt="Enter your name"}`
- **App-Specific Rules**: Restrict snippets to specific applications
- **Statistics Tracking**: Usage count and time saved

### 🌐 Hebrew Support
- **RTL Text Display**: Proper right-to-left rendering in menus and editor
- **Hebrew Calendar**: `{date:hebrew}` for Hebrew dates
- **Hebrew Keyboard Detection**: Auto-detect Hebrew layout (NSEvent+Keyboard)
- **Hebrew Abbreviations**: Support for Hebrew shortcuts (.תז, .שלום)
- **Bilingual UI**: English and Hebrew localization

### ☁️ Sync & Export
- **iCloud Sync**: Auto-sync snippets across devices every 5 minutes
- **JSON Export/Import**: Backup and share snippet collections
- **XML Export**: TextExpander-compatible plist format
- **Conflict Resolution**: Skip, overwrite, or rename strategies
- **Manual Sync**: On-demand sync and restore from iCloud

---

## 🚀 Getting Started

### Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.2+ (for building from source)
- Swift 6.0

### Installation

#### Option 1: Build from Source

```bash
# Clone the repository
git clone https://github.com/relbns/ClipFlow.git
cd ClipFlow

# Build the project
swift build -c release

# The binary will be at:
# .build/release/ClipFlow
```

#### Option 2: Run in Development Mode

```bash
# Build and run
swift run ClipFlow

# Or open in Xcode
open Package.swift
# Then press ⌘R to run
```

### First Launch Setup

1. **Grant Accessibility Permission** (Required for text expansion):
   - Go to: **System Settings → Privacy & Security → Accessibility**
   - Click the lock to make changes
   - Click **+** and add ClipFlow
   - Or use the "Open System Settings" button in ClipFlow → Preferences → Text Expansion

2. **Configure Settings** (⌘,):
   - **General**: Launch at login, max history items (10-100)
   - **Appearance**: Simple vs Organized mode, icons, thumbnails
   - **Text Expansion**: Enable/disable, trigger type, sound feedback
   - **Hotkeys**: Customize all keyboard shortcuts
   - **Sync**: Enable iCloud sync (optional)

3. **Create Your First Snippet** (⌘E):
   - Click **+ Snippet**
   - **Title**: "My Email"
   - **Abbreviation**: `.email` (must start with . ; or /)
   - **Content**: `your@email.com`
   - **Trigger**: Delimiter (space, tab, punctuation)
   - Click **Save**
   - Test: Type `.email[SPACE]` anywhere!

---

## 💡 Usage Examples

### Basic Text Expansion

```
Abbreviation: .email
Content: john@example.com
Trigger: Delimiter

Type: .email[SPACE]
Result: john@example.com
```

### Date Variables

```
Abbreviation: .today
Content: Today is {date:yyyy-MM-dd}
Trigger: Space

Type: .today[SPACE]
Result: Today is 2026-05-10
```

### Hebrew Calendar

```
Abbreviation: .תאריך
Content: {date:hebrew}
Trigger: Space

Type: .תאריך[SPACE]
Result: י״א באייר ה׳תשפ״ו
```

### Cursor Positioning

```
Abbreviation: .log
Content: console.log({cursor})
Trigger: Space

Type: .log[SPACE]
Result: console.log(█) // cursor positioned between parentheses
```

### Custom Variables with Prompts

```
Abbreviation: .hi
Content: Hello {name:prompt="Enter your name"}!
Trigger: Space

Type: .hi[SPACE]
→ Dialog appears: "Enter your name"
Enter: John
Result: Hello John!
```

### App-Specific Rules

```
Abbreviation: .sql
Content: SELECT * FROM users WHERE id = {cursor}
Restrict to Apps: ✓
Apps: TablePlus, DataGrip

→ Only expands in specified database applications
→ Won't expand in other apps
```

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘⇧V | Open main menu |
| ⌘⌃V | Open history menu |
| ⌘⇧B | Open snippets menu |
| ⌘E | Open snippet editor |
| ⌘, | Open preferences |
| ⌘⌥⌫ | Clear clipboard history |
| 1-9, 0 | Quick select menu items |
| Esc | Close any menu |
| ⌥ + Paste | Paste as plain text |
| ⌘ + Paste | Paste without adding to history |

---

## 🎨 UI Customization

### Settings → Appearance

- **View Mode**: 
  - **Simple**: Flycut-style flat list (up to 50 items)
  - **Organized**: Grouped folders (Recent, Images, URLs, Text)
- **Show Icons**: Type indicators (📝 text, 🖼️ images, 🔗 URLs)
- **Show Thumbnails**: Image previews (32x32) and color swatches
- **Number Menu Items**: Keyboard shortcuts 1-9, 0
- **Max Title Length**: 20-100 characters (slider)

### Settings → Text Expansion

- **Enable/Disable**: Toggle text expansion globally
- **Expand After**:
  - Delimiter (space, tab, punctuation) - Recommended
  - Space only
  - Any character
  - Tab only
  - Enter only
- **Case Sensitive**: Match abbreviation case exactly
- **Play Sound**: Audio feedback on expansion
- **Show Notification**: Brief notification on expansion

### Settings → Sync

- **iCloud Sync**: Auto-sync every 5 minutes
- **Export All**: Save all snippets to JSON file
- **Import**: Load snippets from JSON file
- **Conflict Resolution**: Choose skip/overwrite/rename strategy

---

## 🛠️ Development

### Project Structure

```
ClipFlow/
├── Sources/
│   ├── App/                      # App entry point
│   │   ├── ClipFlowApp.swift     # @main SwiftUI app
│   │   └── AppDelegate.swift     # MenuBar setup
│   ├── Core/
│   │   ├── Models/               # Core Data models
│   │   │   ├── ClipItem.swift
│   │   │   ├── Snippet.swift
│   │   │   ├── SnippetGroup.swift
│   │   │   └── AppRule.swift
│   │   ├── Services/             # Business logic
│   │   │   ├── ClipboardMonitor.swift
│   │   │   ├── KeystrokeMonitor.swift
│   │   │   ├── TextExpansionEngine.swift
│   │   │   ├── VariableProcessor.swift
│   │   │   ├── PasteEngine.swift
│   │   │   └── Sync/
│   │   │       ├── SnippetExporter.swift
│   │   │       └── iCloudSyncService.swift
│   │   ├── Storage/
│   │   │   └── CoreDataStack.swift
│   │   └── Extensions/
│   │       ├── String+Hebrew.swift
│   │       ├── Date+Hebrew.swift
│   │       └── NSEvent+Keyboard.swift
│   ├── Features/
│   │   ├── SnippetEditor/        # Snippet management UI
│   │   ├── Settings/             # Preferences windows
│   │   └── MenuBar/              # Menu controller
│   ├── Shared/
│   │   └── Utilities/
│   │       └── LocalizedString.swift
│   └── Resources/
│       ├── Assets.xcassets/
│       └── Localizations/
│           ├── en.lproj/
│           └── he.lproj/
├── Tests/
│   └── ClipFlowTests.swift
├── docs/                         # Documentation
├── Package.swift                 # SPM manifest
└── README.md
```

### Building & Testing

```bash
# Build debug
swift build

# Build release
swift build -c release

# Run tests
swift test

# Run with verbose output
swift build -v

# Clean build
swift package clean
```

### Running in Xcode

1. Open `Package.swift` in Xcode
2. Wait for dependencies to resolve (KeyboardShortcuts, Sparkle)
3. Select "ClipFlow" scheme
4. Build (⌘B)
5. Run (⌘R)

**Note**: Accessibility permissions are required even in development mode for text expansion to work.

### Code Style

- **SwiftLint** configured (see `.swiftlint.yml`)
- **Swift 6.0** strict concurrency (`@MainActor`, actors)
- **Combine** for reactive programming
- **Core Data** for persistence
- **SwiftUI + AppKit** hybrid UI

---

## 🙏 Credits

ClipFlow is built on the foundation of [Clipy](https://github.com/Clipy/Clipy) by [@econa77](https://github.com/econa77).

**What we kept from Clipy:**
- Clipboard monitoring architecture (ClipService concept)
- Snippet data models (enhanced with text expansion)
- Menu bar UI patterns

**What's new in ClipFlow:**
- Real-time text expansion engine
- Modern SwiftUI interface
- Hebrew RTL support
- Cloud sync (iCloud, JSON export)
- TextExpander-compatible variables
- Swift 6.0 & macOS 14+ native
- Custom variables with prompts
- App-specific expansion rules

See [CREDITS.md](CREDITS.md) for full attribution.

---

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

Original Clipy code: [CLIPY-LICENSE](CLIPY-LICENSE)

---

## 🔗 Links

- **Issues**: [GitHub Issues](https://github.com/relbns/ClipFlow/issues)
- **Discussions**: [GitHub Discussions](https://github.com/relbns/ClipFlow/discussions)
- **Changelog**: [CHANGELOG.md](CHANGELOG.md) (Coming Soon)
- **Roadmap**: [IMPLEMENTATION-PLAN.md](IMPLEMENTATION-PLAN.md)

---

Made with ❤️ using [Claude Code](https://claude.ai/code)
