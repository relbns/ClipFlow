# Credits

ClipFlow builds upon the excellent work of the macOS clipboard manager community.

---

## Primary Attribution

### Clipy - Core Foundation

**Project**: [Clipy](https://github.com/Clipy/Clipy)  
**Author**: [@econa77](https://github.com/econa77) and contributors  
**License**: MIT License  

We are deeply grateful to the Clipy team for creating the foundation that ClipFlow builds upon.

**What We Kept (Conceptually)**:
- **Clipboard monitoring architecture** - NSPasteboard polling pattern
- **ClipService concept** - Service-based clipboard monitoring
- **Snippet data models** - Snippet and SnippetGroup structure (enhanced)
- **Menu bar UI patterns** - Dynamic NSMenu construction

**What We Migrated**:
- RxSwift → Combine (native reactive framework)
- Realm → Core Data (Apple's persistence framework)
- CocoaPods → Swift Package Manager
- Swift 5.3 → Swift 6.0 (strict concurrency)
- XIB/Storyboards → SwiftUI (modern UI)
- macOS 10.10+ → macOS 14.0+ (modern features)

---

## Inspiration

### Flycut - UI/UX Inspiration

**Project**: [Flycut](https://github.com/TermiT/Flycut)  
**Inspired Elements**:
- Simple, keyboard-first interface
- Numbered menu items (1-9, 0) for quick selection
- Minimalist approach to clipboard management
- Focus on speed and efficiency

**No Code Used**: UI/UX design inspiration only

---

### TextExpander - Feature Inspiration

**Product**: [TextExpander](https://textexpander.com/) by Smile Software  
**Inspired Elements**:
- Variable syntax `{variable}` and `{variable:format}`
- Fill-in fields `{name:prompt="..."}`
- Trigger character detection
- Statistics tracking

**No Code Used**: Feature concept inspiration only. ClipFlow implements all text expansion from scratch using CGEventTap.

---

## What's New in ClipFlow

### Core Features
- ✨ **Real-time text expansion engine** - Type abbreviations to expand snippets
- 🌐 **Full Hebrew RTL support** - Right-to-left text editing and menu items
- 🔤 **TextExpander-compatible variables** - {date}, {time}, {clipboard}, and more
- ☁️ **Cloud sync** - iCloud sync and JSON export/import
- 🎨 **Modern SwiftUI interface** - Complete UI rewrite with SwiftUI
- 🔀 **Dual UI modes** - Simple (Flycut-style) and Organized (folders)

### Technical Improvements
- **Swift 6.0** - Latest Swift features and concurrency
- **SwiftUI** - Modern, declarative UI framework
- **Combine** - Replaced RxSwift with native Combine
- **Core Data** - Replaced Realm for better integration
- **SPM** - Replaced CocoaPods with Swift Package Manager
- **macOS 14+** - Focused on modern macOS features

---

## Open Source Libraries

ClipFlow uses the following open-source libraries:

- **[KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)** by [@sindresorhus](https://github.com/sindresorhus) - Global hotkey management
- **[Sparkle](https://github.com/sparkle-project/Sparkle)** - Automatic updates

---

## Original Clipy License

Clipy is licensed under the MIT License.

```
MIT License

Copyright (c) 2015 Econa

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## Development

### Claude Code

**Product**: [Claude Code](https://claude.ai/code) by Anthropic  
**Model**: Claude Sonnet 4.5  
**Role**: AI-powered development assistant

This entire project was developed collaboratively with Claude Code, including:
- Architecture design and planning (6 phases, 98 tasks)
- Swift 6.0 implementation with strict concurrency
- SwiftUI + AppKit hybrid interface
- Core Data models and migrations
- Text expansion engine (CGEventTap-based)
- Hebrew RTL support (String+Hebrew, Date+Hebrew, NSEvent+Keyboard)
- iCloud sync service
- Export/import with conflict resolution
- Comprehensive documentation

**Development Period**: May 2026

---

## Contributors

### Core Team
- **[@relbns](https://github.com/relbns)** - Creator and maintainer
- **Claude Sonnet 4.5** - AI development partner

### Community Contributors

Thank you to all contributors who have helped make ClipFlow better!

[//]: # (This section will be auto-generated from GitHub contributors)

---

## Special Thanks

- **The Clipy team** ([@econa77](https://github.com/econa77)) for creating the foundation
- **The Flycut team** for UI/UX inspiration
- **Sindre Sorhus** ([@sindresorhus](https://github.com/sindresorhus)) for KeyboardShortcuts framework
- **The Sparkle Project** for the update framework
- **macOS developer community** for Swift and SwiftUI resources
- **Hebrew-speaking developers** for RTL requirements and testing
- **All our users and testers** for feedback and bug reports

---

*If you feel your contribution should be acknowledged here, please [open an issue](https://github.com/relbns/ClipFlow/issues/new).*
