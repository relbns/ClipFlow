# Credits

## Original Work

ClipFlow is built on the foundation of **[Clipy](https://github.com/Clipy/Clipy)** by [@econa77](https://github.com/econa77) and contributors.

We are deeply grateful to the Clipy maintainers and the open-source community for their excellent work.

---

## What We Kept from Clipy

- **Clipboard monitoring architecture** - The core concept of monitoring NSPasteboard for changes
- **Snippet data models** - Enhanced with text expansion capabilities
- **Menu bar UI patterns** - Adapted and modernized for SwiftUI
- **Realm database approach** - Migrated to Core Data for better Swift integration

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

## Contributors

Thank you to all contributors who have helped make ClipFlow better!

[//]: # (This section will be auto-generated from GitHub contributors)

---

## Special Thanks

- The Clipy team for creating the foundation
- The macOS developer community
- All our users and testers
- Hebrew-speaking developers who provided feedback on RTL support

---

*If you feel your contribution should be acknowledged here, please open an issue or PR.*
