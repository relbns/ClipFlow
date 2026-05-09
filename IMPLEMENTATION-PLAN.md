# ClipFlow Implementation Plan

**Current Phase**: Phase 4 - Hebrew & i18n (Phase 3 UI Complete!)

**Rules:**
1. Work tasks in phase order - never skip ahead
2. Check the box ONLY after code is merged to main
3. Create GitHub issue for each task before starting
4. Never work on main - always use feat/* branch

---

## Phase 1: Foundation (Weeks 1-3)

### Setup & Architecture
- [x] #1 Create new repo: `gh repo create relbns/ClipFlow --public`
- [x] #2 Setup GitHub labels (type, priority, effort, phase, component)
- [ ] #3 Create 3 project boards: MVP, Phase 2, Backlog (needs auth)
- [x] #4 Setup .claude/ folder: commands, skills, hooks, settings.json
- [x] #5 Write core documentation files (CLAUDE.md, README, CREDITS)
- [x] #6 Create Xcode project with SPM (Swift 6.0, macOS 14+)
- [x] #7 Setup .github/workflows: ci.yml (build + test)
- [x] #8 Add SwiftLint configuration

### Core Data Models
- [x] #9 Create Core Data model: ClipItem, Snippet, SnippetGroup
- [x] #10 Implement CoreDataStack with migrations
- [x] #11 Create Snippet model with abbreviation, trigger
- [x] #12 Create SnippetGroup model with sync metadata
- [ ] #13 Create Variable model (date, time, clipboard, custom)
- [ ] #14 Add Statistics model (use count, last used)

### Core Services (Phase 1)
- [x] #15 ClipboardMonitor.swift (Combine-based, NSPasteboard)
- [x] #16 PasteEngine.swift (async/await, Cmd+V simulation)
- [x] #17 HotkeyManager.swift (KeyboardShortcuts framework)
- [x] #18 AppContextMonitor.swift (NSWorkspace, frontmost app)

### Basic UI (AppKit/SwiftUI Hybrid)
- [x] #19 ClipFlowApp.swift (@main, SwiftUI entry)
- [x] #20 AppDelegate.swift (MenuBar setup, status item)
- [x] #21 MenuBarController.swift (menu building, AppKit bridge)
- [x] #22 Basic clipboard menu (text items only)
- [x] #23 Settings window skeleton (SwiftUI tabs)

---

## Phase 2: Text Expansion (Weeks 4-6)

### Text Expansion Engine
- [x] #24 KeystrokeMonitor.swift (CGEventTap, buffer management)
- [x] #25 TextExpansionEngine.swift (abbreviation matching)
- [x] #26 VariableProcessor.swift ({date}, {time}, {clipboard})
- [x] #27 Trigger detection (space, delimiter, any char)
- [x] #28 Backspace deletion before paste
- [x] #29 Sound feedback on expansion
- [x] #30 Statistics tracking (use count, chars saved)

### Advanced Variables
- [x] #31 Date formatting ({date:yyyy-MM-dd}, {date:hebrew})
- [x] #32 Time formatting ({time:HH:mm})
- [x] #33 Clipboard variable ({clipboard})
- [ ] #34 Cursor positioning ({cursor})
- [ ] #35 Custom variables with prompts
- [ ] #36 Fill-in fields dialog (NSAlert with text fields)

### App-Specific Rules
- [ ] #37 App rule system (bundle ID matching)
- [ ] #38 UI for selecting apps in snippet editor
- [ ] #39 Filter expansion based on frontmost app

---

## Phase 3: UI & Polish (Weeks 7-9)

### Snippet Editor (Full Featured)
- [x] #40 3-panel layout: Sidebar, Editor, Inspector
- [x] #41 Sidebar: groups + snippets, drag & drop reorder
- [x] #42 Content editor: title, abbreviation, content
- [x] #43 Variable insertion buttons
- [x] #44 Inspector panel: trigger settings, app rules
- [x] #45 Real-time abbreviation validation
- [x] #46 Statistics display (uses, time saved)
- [x] #47 Duplicate snippet feature
- [x] #48 Search/filter in sidebar

### Settings UI (Complete)
- [x] #49 General settings tab
- [x] #50 Appearance settings tab (Simple vs Organized mode)
- [x] #51 Text Expansion settings tab
- [x] #52 Hotkeys settings tab
- [x] #53 Sync settings tab
- [x] #54 Advanced settings tab
- [x] #55 Accessibility permission check + open System Settings

### MenuBar UI (Both Modes)
- [ ] #56 Simple mode (flat list)
- [ ] #57 Organized mode (folders)
- [ ] #58 Search bar with instant filter
- [x] #59 RTL support for Hebrew items
- [ ] #60 Image thumbnails
- [ ] #61 Color code preview
- [ ] #62 Keyboard shortcuts (1-9, 0)

---

## Phase 4: Hebrew & i18n (Week 10)

### Hebrew Support
- [x] #63 String+Hebrew.swift (isHebrew, isRTL detection)
- [x] #64 Date+Hebrew.swift (Hebrew calendar formatting)
- [x] #65 NSEvent+Keyboard.swift (Hebrew layout detection)
- [x] #66 RTL text editing in snippet editor
- [x] #67 RTL menu items
- [ ] #68 Hebrew abbreviations support

### Localization
- [x] #69 en.lproj/Localizable.strings
- [x] #70 he.lproj/Localizable.strings
- [ ] #71 All UI strings localized (strings ready, UI needs updates)
- [x] #72 Settings for language preference

---

## Phase 5: Sync & Export (Weeks 11-12)

### File Export/Import
- [ ] #73 JSON export (single group)
- [ ] #74 JSON export (all snippets)
- [ ] #75 JSON import with validation
- [ ] #76 Conflict resolution UI
- [ ] #77 XML export (TextExpander compatible)

### iCloud Sync
- [ ] #78 iCloudSyncService.swift
- [ ] #79 Enable/disable toggle in settings
- [ ] #80 Auto-sync on change
- [ ] #81 Conflict resolution (cloud wins)
- [ ] #82 Sync status indicator

---

## Phase 6: Testing & Release (Weeks 13-14)

### Testing
- [ ] #83 Unit tests: VariableProcessor
- [ ] #84 Unit tests: TextExpansionEngine
- [ ] #85 Unit tests: ClipboardMonitor
- [ ] #86 UI tests: Snippet Editor
- [ ] #87 UI tests: Settings
- [ ] #88 Manual testing checklist

### Release Preparation
- [ ] #89 App icon design (Big Sur style)
- [ ] #90 MenuBar icon (monochrome + color variants)
- [ ] #91 README.md with screenshots
- [ ] #92 CREDITS.md (thank Clipy)
- [ ] #93 LICENSE files (MIT + CLIPY-LICENSE)
- [ ] #94 GitHub Release workflow
- [ ] #95 Notarization script
- [ ] #96 Sparkle updates integration
- [ ] #97 Homebrew formula
- [ ] #98 Demo video

---

**Total MVP tasks**: ~77 (Phases 1-5)
**Total with testing & release**: ~98
**Estimated time**: 14 weeks (3.5 months)
