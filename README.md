# ClipFlow

> Modern clipboard manager + text expander for macOS. Open source, Hebrew-ready, SwiftUI.

[![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## ✨ Features

### Clipboard History
- 📋 Unlimited clipboard history (configurable limit)
- 🖼️ Support for text, images, files, URLs
- 🔍 Instant search across all items
- 🎨 Color code preview
- 📌 Pin favorite items

### Text Expansion
- ⚡ Real-time text expansion (like TextExpander)
- 🔤 Variables: `{date}`, `{time}`, `{clipboard}`, `{cursor}`
- 📝 Custom fill-in fields
- 🎯 App-specific snippets
- 🔊 Sound feedback (optional)

### Hebrew Support
- 🇮🇱 Full RTL (right-to-left) support
- 📅 Hebrew calendar dates
- ⌨️ Hebrew abbreviations
- 🌐 Bilingual UI (Hebrew/English)

### Modern UI
- 🎨 SwiftUI + AppKit hybrid
- 🔀 Two modes: Simple (Flycut-style) or Organized (folders)
- ⌨️ Keyboard shortcuts (1-9, 0)
- 🌓 Light & Dark mode

### Sync & Sharing
- ☁️ iCloud sync (optional)
- 📤 Export/Import JSON
- 🔗 Share via Gist (coming soon)

---

## 🚀 Installation

### Homebrew (Recommended)
```bash
brew install clipflow
```

### Manual Download
Download the latest release from [GitHub Releases](https://github.com/relbns/ClipFlow/releases)

---

## 📖 Quick Start

1. **Launch ClipFlow** - appears in menu bar
2. **Copy something** - automatically saved to history
3. **Open menu** - `⌘⇧V` (customizable)
4. **Create snippet** - Open Snippet Editor (`⌘E`)
   - Title: "Email signature"
   - Abbreviation: `.sig`
   - Content: Your signature text
5. **Use snippet** - Type `.sig` followed by space anywhere!

---

## ⌨️ Default Hotkeys

| Action | Hotkey |
|--------|--------|
| Main Menu | `⌘⇧V` |
| History Menu | `⌘⌃V` |
| Snippets Menu | `⌘⇧B` |
| Snippet Editor | `⌘E` |
| Preferences | `⌘,` |
| Clear History | `⌘⌥⌫` |

---

## 🎯 Roadmap

- [x] Clipboard history
- [x] Text expansion engine
- [x] Hebrew RTL support
- [x] iCloud sync
- [ ] JavaScript snippets
- [ ] iOS companion app
- [ ] Team collaboration

See [IMPLEMENTATION-PLAN.md](IMPLEMENTATION-PLAN.md) for detailed roadmap.

---

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

---

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

---

## 🙏 Credits

ClipFlow is built on the foundation of [Clipy](https://github.com/Clipy/Clipy) by @econa77.

See [CREDITS.md](CREDITS.md) for full attribution.

---

## 💬 Community

- **Issues**: [GitHub Issues](https://github.com/relbns/ClipFlow/issues)
- **Discussions**: [GitHub Discussions](https://github.com/relbns/ClipFlow/discussions)

---

Made with ❤️ for productivity enthusiasts
