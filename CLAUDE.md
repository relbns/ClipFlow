# ClipFlow — Claude Code Project Guide

## What Is This Project?

ClipFlow is a modern clipboard manager and text expander for macOS. It combines clipboard history management with real-time text expansion, supporting variables, Hebrew RTL, and cloud sync.

**Target Users**: Developers, power users, Hebrew speakers, productivity enthusiasts

**Key Differentiators**:
- Open source (competitors cost $30-50/year)
- Text expansion (Maccy is clipboard-only)
- Hebrew RTL support (TextExpander lacks this)
- Simple + Organized UI modes (user choice)

---

## Master Documents

- **IMPLEMENTATION-PLAN.md** — task checklist, read at start of every session
- **docs/FULL-PRD.md** — complete requirements
- **docs/UI-SPEC.md** — detailed UI mockups
- **docs/TEXT-EXPANSION-SPEC.md** — how expansion works

---

## Hard Rules

### 1. No Code Without an Issue

Every change goes through:
```
gh issue create → git checkout -b feat/* → code → commit → merge → gh issue close
```

A hook blocks `Edit`/`Write` on `main`. Never work on main directly.

### 2. Plan Before You Act

Before any code change:
1. Present a plan
2. Wait for explicit approval
3. Only then proceed

Exception: "continue working" on already-approved plan.

### 3. Read IMPLEMENTATION-PLAN.md First

At session start:
1. Read `IMPLEMENTATION-PLAN.md`
2. Find current phase and next unchecked task
3. Work tasks in order - never skip phases
4. Check box ONLY after merged to main

### 4. Agent Files

Before working on any domain, read the relevant agent file:

| Task Type | Agent File |
|-----------|-----------|
| macOS app dev | `agents/macos-developer.md` |
| SwiftUI | `agents/swiftui-architect.md` |
| Text expansion | `agents/text-expansion-expert.md` |
| Hebrew/i18n | `agents/i18n-specialist.md` |
| Testing | `agents/qa-engineer.md` |
| Release | `agents/release-manager.md` |

### 5. Language

Always respond in **Hebrew or English** only.

---

## Tech Stack

- **Language**: Swift 6.0
- **UI**: SwiftUI (primary) + AppKit (MenuBar, CGEventTap)
- **Minimum macOS**: 14.0 Sonoma
- **Dependencies**: SPM only
- **Database**: Core Data
- **Reactive**: Combine (native)
- **Hotkeys**: KeyboardShortcuts (Sindre Sorhus)
- **Testing**: XCTest
- **CI/CD**: GitHub Actions

---

## Definition of Done

A task is complete ONLY when:
- [ ] Code written and works locally
- [ ] Unit tests pass (if applicable)
- [ ] No SwiftLint warnings
- [ ] Builds on CI
- [ ] Documented (if public API)
- [ ] Merged to main
- [ ] GitHub issue closed
- [ ] Checkbox in IMPLEMENTATION-PLAN.md checked

---

## Credits

ClipFlow is built on the foundation of [Clipy](https://github.com/Clipy/Clipy).
See `CREDITS.md` for full attribution.
