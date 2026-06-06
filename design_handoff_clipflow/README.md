# Handoff: ClipFlow — macOS Menubar Clipboard Manager + Text Expander

## Overview
ClipFlow is a quiet, native-feeling macOS **menubar** app that combines two products in one:

1. **Clipboard history** — every copy is stored, browsable from a popover, recallable via global hotkey.
2. **Text expansion (snippets)** — type an abbreviation like `.sig` and it's replaced with a longer block of text, optionally with variables (`{date}`, `{clipboard}`, `{prompt:Name}`).

Hebrew / RTL is a first-class citizen.

This handoff covers six surfaces:

| # | Surface | Window kind | Trigger |
|---|---|---|---|
| 1 | MenuBar dropdown | Popover anchored to status item | Click status icon or global hotkey `⌃⌘V` |
| 2 | Snippet Editor | Standard window, 1080×700 | Menu → "Snippet Editor…" or `⌘E` |
| 3 | Preferences | Tab-strip window, 760×620 | Menu → "Preferences…" or `⌘,` |
| 4 | Welcome / Onboarding | Modal window, 780×520 | First launch |
| 5 | About | Small modal, 560×680 | App menu → About ClipFlow |
| 6 | Status item | NSStatusItem in menubar | Always present |

## About the Design Files
The files in `design/` are **design references created as inline-JSX HTML prototypes** — they show the intended look and behavior, not production code to copy directly.

Your task is to **recreate these designs in the target codebase**. ClipFlow is a macOS-only product, so the natural target is **SwiftUI + AppKit** (AppKit for `NSStatusItem`, `NSPopover`, and the global-keystroke event tap; SwiftUI for screen content). The prototype's CSS variables and React components should map cleanly to a SwiftUI `Theme` environment object and a small library of view modifiers.

If the team has chosen a different stack (Electron + React, Tauri + Vue, etc.), the design tokens transfer 1:1 — the prototype already uses CSS variables for Dark + Light theming and was built to be portable.

## Fidelity
**High-fidelity.** Final colors, typography, spacing, density, and component anatomy are all locked. Recreate pixel-perfectly inside the chosen stack's idioms — don't reach for a generic UI library and adjust later.

A few things are intentionally still placeholder:
- App icons inside the "App rules" inspector are blank rectangles — fetch the real app icons via `NSWorkspace.shared.icon(forFile:)` at runtime.
- "Today is" / sync timestamps are static — wire to live data.
- Hebrew calendar string is illustrative; use the OS's locale formatter.

---

## Brand & Identity

### Name
**ClipFlow**

### Tagline (used on Welcome)
"Everything you copy. Anything you type often."

### App icon / Logo
Two stacked **clipboards** rendered in indigo gradient — a smaller back clipboard rotated ~8°, a larger front clipboard with three white "lines of text" of decreasing length. The back one peeks above and to the right.

- **Source SVG**: `design/components/settings.jsx`, function `ClipFlowMark`. Accepts `size` (px) and `rounded` (default `true` — wraps in 14px-radius dark gradient tile for the macOS icon).
- For the **app's `.icns` asset**, render `ClipFlowMark` at 1024×1024 inside the rounded squircle background. The fill gradient is `linear-gradient(135deg, oklch(.74 .17 280), oklch(.5 .19 268))`.
- For **inline brand marks** (About hero, Welcome screen) pass `rounded={true}` for the squircle tile.

### Menubar status icon
**Monochrome** outline version of the same two-clipboards motif — `currentColor` only, ~14×14 in a 16×16 status item slot. Source: the `it.i === 'clip'` SVG inside `StatusBarStrip` in `design/components/menubar.jsx`.

In macOS this should be a **template image** (`NSImage.template = true`) so the OS handles light/dark menubar inversion automatically.

---

## Design Tokens

All tokens live in the `<style>` block of `design/ClipFlow UI Review.html` under `.theme-dark` and `.theme-light` classes. **Implement these as a `Theme` environment value, not as hardcoded `Color`s.**

### Accent (constant across themes)
| Token | Value |
|---|---|
| Brand / Accent | `oklch(0.60 0.17 272)` (≈ `#7B71FF`) |
| Brand light | `oklch(0.74 0.17 280)` |
| Brand deep | `oklch(0.50 0.19 268)` |
| Warning (banner) | `oklch(0.70 0.17 60)` (≈ amber) |
| Success | `oklch(0.70 0.17 145)` (≈ green) |
| Danger | `#ff7a73` |

### Surfaces — Dark
| Token | Value |
|---|---|
| `--surface` | `#1d1d22` (main window body) |
| `--surface-alt` | `#1a1a1f` (sidebars, inspector) |
| `--surface-deep` | `#15151a` (editor textarea, About body) |
| `--input-bg` | `rgba(0,0,0,.30)` |
| `--popover-bg` | `linear-gradient(180deg, rgba(46,46,52,.92), rgba(34,34,40,.92))` + 28px backdrop blur, 160% saturate |
| `--titlebar-bg` | `linear-gradient(180deg, #2c2c33, #232328)` |
| `--statusbar-bg` | `linear-gradient(180deg, rgba(40,40,46,.72), rgba(28,28,32,.72))` + 20px backdrop blur, 140% saturate |

### Surfaces — Light
| Token | Value |
|---|---|
| `--surface` | `#f6f6f8` |
| `--surface-alt` | `#ececef` |
| `--surface-deep` | `#ffffff` |
| `--input-bg` | `#ffffff` |
| `--popover-bg` | `linear-gradient(180deg, rgba(252,252,254,.85), rgba(244,244,247,.85))` + 28px backdrop blur, 160% saturate |
| `--titlebar-bg` | `linear-gradient(180deg, #f1f1f3, #e6e6e9)` |

### Text — Dark
| Token | Value |
|---|---|
| `--text-strong` | `#fff` |
| `--text` | `rgba(255,255,255,.92)` |
| `--text-mid` | `rgba(255,255,255,.72)` |
| `--text-muted` | `rgba(255,255,255,.58)` |
| `--text-subtle` | `rgba(255,255,255,.46)` |
| `--text-label` | `rgba(255,255,255,.42)` (Section caps) |
| `--text-faint` | `rgba(255,255,255,.38)` |

### Text — Light
| Token | Value |
|---|---|
| `--text-strong` | `#0a0a0c` |
| `--text` | `rgba(0,0,0,.86)` |
| `--text-mid` | `rgba(0,0,0,.66)` |
| `--text-muted` | `rgba(0,0,0,.55)` |
| `--text-subtle` | `rgba(0,0,0,.46)` |
| `--text-label` | `rgba(0,0,0,.42)` |
| `--text-faint` | `rgba(0,0,0,.36)` |

### Fills & Strokes
Dark: `--fill-soft .04` · `--fill-1 .07` · `--fill-2 .10` · `--fill-3 .16` (all white over black)
Light: `--fill-soft .02` · `--fill-1 .05` · `--fill-2 .07` · `--fill-3 .11` (all black over white)
Strokes: `--stroke` `.08`/`.10`, `--stroke-soft` `.06`/`.07` (D / L)

### Shadows
Dark:
- `--popover-shadow`: `0 24px 60px -10px rgba(0,0,0,.55), 0 0 0 .5px rgba(255,255,255,.10), inset 0 1px 0 rgba(255,255,255,.06)`
- `--window-shadow`: `0 30px 80px -10px rgba(0,0,0,.5), 0 0 0 .5px rgba(255,255,255,.10)`

Light:
- `--popover-shadow`: `0 24px 60px -10px rgba(0,0,0,.22), 0 0 0 .5px rgba(0,0,0,.10), inset 0 1px 0 rgba(255,255,255,.5)`
- `--window-shadow`: `0 30px 80px -10px rgba(0,0,0,.22), 0 0 0 .5px rgba(0,0,0,.10)`

### Typography
| Role | Family | Size | Weight | Line-height |
|---|---|---|---|---|
| Window title | SF Pro Text → Inter | 13 | 500 | 1 |
| Section caps | SF Pro Text | 10.5 | 600 | 1, letter-spacing `.06em`, uppercase |
| Body / row | SF Pro Text | 13 | 400 (500 when selected) | 1.4 |
| Row subtitle | SF Pro Text | 11 | 400 | 1 |
| Inspector label | SF Pro Text | 11.5 | 400 | — |
| About product name | SF Pro Display | 28 | 700, letter-spacing `-.01em` | 1.15 |
| Welcome hero | SF Pro Display | 28 | 600, letter-spacing `-.01em` | 1.15 |
| Kbd / code / abbreviation | JetBrains Mono → SF Mono / Menlo | 11–14 | 500 | 1 |

**Use the system "SF Pro" via `Font.system(...)` in SwiftUI.** The prototype falls back to Inter when SF isn't available. Do **not** ship Inter in the macOS build.

### Spacing & Density
- Popover width: **340 px** (tight; do not widen)
- Popover row: **28–30 px** tall, 6 px vertical padding, 10 px horizontal padding, 6 px row radius, 10 px gap between glyph and text
- Section gutter: 14 px (caps padding)
- Window padding: 22 px horizontal in editor body, 26 px in Preferences body, 28 px in Welcome
- Corner radius: **12 px** windows, **7 px** popover input, **6 px** rows/buttons/inputs, **8 px** inspector cards, **999 px** chips/toggles

### Iconography
Single-weight monochrome line set, 24×24 viewBox, `strokeWidth=1.6` default, round caps & joins. **Never use emoji** for chrome icons. Source: `design/components/icons.jsx`.

Required icons (already drawn): Search, Clock, Image, Text, Link, Swatch, Bolt, Star, Pin, Folder, Chevron (right + down), Plus, Cmd, Gear, Trash, Power, Cloud, Check, Circle, Key, Sparkles, Bracket, ArrowDown, Lock, Dot, Hebrew (ה glyph).

**In SwiftUI**, prefer `Image(systemName:)` from SF Symbols where the glyph matches (Symbols `doc.on.clipboard`, `magnifyingglass`, `clock`, `photo`, `text.alignleft`, `link`, `paintpalette`, `bolt`, `star`, `pin`, `folder`, `chevron.right`, `plus`, `command`, `gearshape`, `trash`, `power`, `cloud`, `checkmark`, `circle`, `key`, `sparkles`, `curlybraces`, `arrow.down`, `lock`). Only fall back to the custom SVGs when no Symbol matches.

---

## Surface 1 — MenuBar dropdown (popover)

**Anchor**: `NSPopover` from the status item, bottom edge, with a 10px arrow caret that points up at the status item.

**Behavior**:
- Opens on left-click of status icon, or on global hotkey `⌃⌘V`.
- Closes on `Esc`, click outside, or after the user activates an item.
- Numeric keys `1`–`9`, `0` activate items 1–10 in current view (paste + close).
- `⌘1`–`⌘9` activate pinned items (Organized mode).
- `↑`/`↓` move selection; `Return` activates; `⌫` clears, `⌥⌫` deletes hovered item.
- `⌘F` focuses search; typing focuses search automatically.
- **Paste behavior**: activating an item writes it to `NSPasteboard.general` AND synthesizes a `⌘V` into the frontmost app (the user expects paste-on-pick, not copy-back-to-clipboard).

### 1a. Simple mode (flat list)
**Width 340, height fits content (max ≈ 560 before scroll).**

Anatomy top → bottom:
1. **Search field** — height 28, 7px radius, magnifier glyph (13×13) leading, `⌘F` kbd hint trailing. Placeholder: `"Search clipboard…"`.
2. **Section cap** — `RECENT CLIPS` (uppercase, 10.5/600/.06em letter-spacing, `--text-label`). Right side shows `"14 items"` (non-uppercase, `--text-subtle`).
3. **Rows** — 10 visible. Each row has:
   - 26×26 thumbnail tile (5px radius, `--fill-1` bg). For images: actual thumbnail. For colors: solid swatch (16×16 inner) with subtle inset stroke. For text/links/code: monochrome glyph centered.
   - Title (one line, ellipsis). Code clips render the title in mono.
   - Subtitle (one line, ellipsis, `--text-subtle`): `copied 12s ago • Safari`.
   - Numeric `kbd` chip on trailing edge (1–9, then 0).
   - Selected row uses background `color-mix(oklch(.6 .17 272) 22%, transparent)` and slightly bolder title.
4. **Divider** (1px, `--stroke`).
5. **Footer rows** — 28 tall, flat list, leading glyph 14×14:
   - Snippet Editor… (`⌘E`)
   - Preferences… (`⌘,`)
   - *(divider)*
   - Clear history
   - Quit ClipFlow (`⌘Q`)

### 1b. Organized mode
Same shell as Simple but with categories:
- **Pinned** section — 2 rows (no kbd, `⌘1`/`⌘2` chips instead). Pin icon leading.
- **Categories** — 5 group rows (Recent, Images, Links, Colors, Text). Each has a colored 22×22 tile (accent ×22% bg, accent fg), count chip (e.g. `14`), trailing chevron-right. Tapping drills into a filtered view.
- **Snippets** — 2 rows showing snippet title + abbreviation as mono trailing label.
- **Mode toggle** — segmented control at footer: `[Simple | Organized]`. The selected segment gets `--seg-selected` background and `--seg-shadow`.

Category accent colors:
| Category | Accent (oklch L C H) |
|---|---|
| Recent | `.78 .14 70` |
| Images | `.74 .14 200` |
| Links  | `.78 .14 145` |
| Colors | `.78 .12 320` |
| Text   | `.78 .12 30` |

### 1c. Hebrew / RTL
All of Simple mode mirrored:
- `direction: rtl` on popover root.
- Numeric kbd chips stay LTR (Unicode bidi isolate `‎` / `\u200E` on the numeric).
- Mixed-language content (`John: שלום, מתי תהיה זמין?`) uses `<bdi>` so punctuation sits correctly.
- Footer items mirror — glyph moves to right, kbd to left.
- Placeholder: `"חיפוש בלוח ובקטעים…"`.
- Search magnifier swaps to the leading (now right) edge.

In SwiftUI: `.environment(\.layoutDirection, .rightToLeft)` on the popover root when locale is Hebrew/Arabic; don't manually flip — let the system mirror.

---

## Surface 2 — Snippet Editor

**1080 × 700**, standard `NSWindow` with traffic lights, no fullscreen button needed.

### Title bar
- Standard 38px height titlebar, traffic lights leading.
- Centered title: `Snippet Editor — <current snippet name>`.
- Trailing toolbar: `[+ New]`, `[Duplicate]`, divider, `[☁ Synced]` button (shows sync state).

### Three-column layout (`230px | 1fr | 280px`)

#### Left sidebar (230px, `--surface-alt`)
- Filter field at top.
- Library group:
  - ★ Favorites · 6
  - ⏱ Recently used · 22
- Groups group (with `+` button on header):
  - Personal (expanded — shows Email signature [selected], Address — home, Today's date)
  - Code (expanded — React component scaffold, console.log, Swift property wrapper)
  - Hebrew · עברית (collapsed)
  - Customer support (collapsed)
- Footer: `☁ iCloud · synced 2m ago` (11px, `--text-subtle`).

#### Center editor
- Large editable title (22/600).
- Meta row: folder breadcrumb, "Used 184 times · saved ≈ 27 min", "Updated yesterday" — all `--text-muted` 12px, separated by 3px round dots.
- **Trigger row** — full-width card (`--fill-soft` bg, `--stroke` border, 8px radius):
  - Left: Abbreviation. Mono `.sig` with leading dot in accent color. Helper text: `must start with . ; or /`.
  - Middle: Trigger select (`Space, Tab or Enter`).
  - Right: Status toggle + label.
- **Variable toolbar** — 5 chips: `{date}`, `{time}`, `{clipboard}`, `{cursor}`, `{prompt:Name}`. Chip bg `color-mix(accent 30%, transparent)`, mono 12px, 4px radius. Hint trailing: `{date:yyyy-MM-dd} for custom format`.
- **Editor body** — `--surface-deep` background, 8px radius, 16px padding, 14px text, line-height 1.55. Pre-filled sample shows:
  - "Best,"
  - "Ronen Ben-Ami" (bold)
  - "Product Engineer · ClipFlow"
  - "m: {prompt:Phone}" (chip inline)
  - "w: clipflow.app"
  - Sent on / at line with `{date:EEEE, MMM d}` and `{time:HH:mm}` chips
  - **Visible 1.5×16 caret** in accent color showing `{cursor}` insertion point.
- **Status bar** (28 tall, top stroke): `Plain text · 9 lines · 142 chars · 2 variables`, trailing `● Saved` (green dot + "Saved" label).

#### Right inspector (280px, `--surface-alt`)
Three stacked blocks separated by top-stroke borders. Each block has a `TITLE` cap (uppercase 10.5/600).

**Trigger block**:
- Field "Abbreviation prefix" → Select `Period (.)`.
- Field "Fires on" with hint → 6-cell grid of segmented toggles: `Space`(on) `Tab`(on) `Enter`(on) `Punct.`(off) `Any`(off) `Manual`(off).
- Field "Cursor placement" → Select `Wherever {cursor} is`.

**App rules block**:
- Header row: "Restrict to apps" + toggle (on).
- 4 app cards (16×16 icon placeholder, name, `allow`/`deny` label): Mail (allow), Slack (allow), Safari (allow), Xcode (deny).

**Statistics block**:
- 2×2 stat grid: `184 expansions`, `27 min time saved`, `Mail top app`, `May 9 last used`.

### Editor behavior
- **Auto-save** with 400ms debounce. Status pill flips to amber `Saving…` then back to green `Saved` when done.
- **Variable insertion**: clicking a chip inserts at caret position; arrow key past a chip deletes it as one unit (no half-deletion).
- **Validation**: abbreviation must start with `.`, `;`, or `/`. Show inline red helper text below the field when invalid; disable save.
- **Conflict warning**: if the typed abbreviation matches another enabled snippet, show an amber inline banner above the trigger row: `"This abbreviation conflicts with «Today's date» — only one will fire."` with a `[Resolve]` button.
- **Live preview** (when Settings → Expansion → "Live preview" is on): hovering the Status pill for 200ms shows a floating preview rendered with current variable values.

---

## Surface 3 — Preferences

**760 × 620**, standard window.

### Tab strip (top, 10px vertical padding, `--titlebar-bg`)
Each tab is a 70px-wide card: 28×28 colored icon + 11px label. Selected tab gets `--fill-2` background.

| Tab | Icon | Accent |
|---|---|---|
| General | gear | `oklch(.55 .03 250)` |
| Appearance | star | `oklch(.65 .12 30)` |
| Expansion *(selected in mock)* | bolt | `oklch(.6 .17 272)` |
| Hotkeys | key | `oklch(.55 .12 145)` |
| Sync | cloud | `oklch(.6 .14 220)` |
| Privacy | lock | `oklch(.55 .12 200)` |
| Language | hebrew-ה | `oklch(.6 .14 320)` |

### Body (Expansion tab shown)

**Accessibility permission banner** at top, ONLY when permission is missing. Warm-tone:
- Background: `color-mix(oklch(.7 .17 60) 20%, transparent)`
- Border: `color-mix(oklch(.7 .17 60) 40%, transparent)`, 1px solid, 10px radius
- Lock icon leading, title `Accessibility access required`, body `ClipFlow needs Accessibility permission…`, primary button trailing: `Open System Settings`.
- Tapping the button calls the macOS deeplink: `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`.

**Settings rows** (`180px | 1fr` two-column layout, 1px `--stroke-soft` bottom borders, 12px vertical padding):

1. **Text expansion** — toggle (on) + label `On — using ⌥⌘V to undo last expansion`.
2. **Default trigger** — segmented control: `[Delimiter | Space ✓ | Any char | Tab | Enter]`. Selected has `--seg-selected` bg.
3. **Sound feedback** — toggle (off). Hint: "Quiet click when an abbreviation expands."
4. **Backspace cancels** — toggle (on). Hint: "Press backspace immediately after expansion to revert to the abbreviation."
5. **Excluded apps** — pill list (1Password, Terminal, Bitwarden), each pill 12×12 app-icon thumbnail + name + `×` close, plus a dashed-border `+ Add app` pill that opens an app picker (`NSOpenPanel` filtered to `.app`).
6. **Live preview** — toggle (on) + label `Floating preview · 200 ms hold`.

### Other tabs (not designed yet — follow same pattern)
- **General**: Launch at login, Update channel, Reset history.
- **Appearance**: Theme (System/Light/Dark), Density (Comfortable/Compact), Show count badges.
- **Hotkeys**: Global hotkey (`⌃⌘V`), Pin to top 1 / 2 / 3, Open editor (`⌘E`).
- **Sync**: iCloud account row + Sync snippets / Sync history toggles + last sync time.
- **Privacy**: Excluded apps from history, Exclude password-manager fields (default on), Excluded data types (passwords/credit-cards detected by heuristic), Retention policy.
- **Language**: UI language, Date/calendar (Gregorian + Hebrew), Numeric direction in RTL.

---

## Surface 4 — Welcome / Onboarding

**780 × 520**, modal-style (no traffic lights centered title, just the three buttons).

Split into two halves:

### Left (visual, 50%)
- Background: `radial-gradient(120% 80% at 30% 20%, oklch(.45 .15 285), oklch(.25 .08 280) 60%, oklch(.18 .04 270) 100%)`.
- 32×32 logo + "ClipFlow" wordmark top.
- Hero copy: **"Everything you copy. / Anything you type often."** (28/600, 2-line break).
- Sub: "A quiet menubar app for clipboard history and abbreviation snippets — with first-class Hebrew & RTL."
- Decorative mini-preview of the popover in the bottom-right corner, rotated -6°, scaled 0.78, with deep drop-shadow. Click-through (`pointer-events: none`).

### Right (steps, 50%)
- Section cap: `THREE QUICK STEPS`.
- 3 step cards stacked. Each has:
  - 28×28 round step badge: done = green check, active = accent gradient circle with white number, idle = `--fill-1` with subtle number.
  - Active step gets `--fill-soft` bg + accent-tinted 1px border + 10px radius.

The three steps:
1. **(done) Pin ClipFlow to your menubar** — "ClipFlow lives up here — there's no Dock icon. Drag the menubar item to where you'd like."
2. **(active) Grant Accessibility permission** — "Required so snippets can expand as you type. We never read passwords or secure fields."
3. **(idle) Try your first snippet** — "We've added `.dd` for today's date. Type it anywhere, then press space."

### Footer
- Left: toggle (on) + "Launch at login".
- Right: `[Skip tour]` `[Open System Settings →]` (primary).

### Behavior
- Active step advances as the user completes each one.
- After step 3, replace the right column with a "You're ready" success state and a "Close" button.
- Welcome opens only when no preferences file exists yet OR when triggered from Help → "Run Welcome again".

---

## Surface 5 — About ClipFlow

**560 × 680**, small fixed window, NOT resizable.

Layout:
1. **Hero** — 128×128 squircle (28px radius) with the indigo gradient + 92px logo centered. Drop shadow: `0 30px 50px -12px oklch(.45 .19 270 / .55)`. Inset highlight on top edge.
2. **Product name** — "ClipFlow" (28/700/letter-spacing -.01em).
3. **Tagline** — "Modern clipboard manager + text expander" (13.5, muted).
4. **Version row** — `Version 1.0.0` + amber `ALPHA` pill (uppercase 10.5/600, `color-mix(oklch(.7 .17 60) 25%, transparent)` bg, `oklch(.7 .15 60)` text).
5. **Hairline divider**.
6. **Credits — Creator**:
   - "Ariel Benesh — Creator & Developer" (28×28 accent tile with person glyph).
7. **Credits — Built on the shoulders of giants**:
   - **Clipy** — "Core clipboard architecture" (green tile).
   - **Flycut** — "UI/UX inspiration for Simple mode" (orange tile).
8. **Footer** (top stroke):
   - 3 link-buttons: `🔗 GitHub`, `📄 Full Credits`, `⚙ License`. Use accent color, no underline, 6px padding.
   - Copyright: `© 2026 ClipFlow · Made with care in Tel Aviv`.

### Behavior
- "Full Credits" opens an inline scrollable list in the same window (Anthropic-style about screen). Sources of attribution: open-source libraries with their licenses.
- "License" opens the EULA in the system PDF viewer.
- "GitHub" opens the repo URL.

---

## Cross-cutting behaviors

### Hotkeys
| Hotkey | Action |
|---|---|
| `⌃⌘V` | Toggle the menubar popover (configurable). |
| `⌘1`–`⌘9` | Paste pinned item N (popover open). |
| `1`–`9`, `0` | Paste item N from current list. |
| `⌘F` | Focus search inside popover. |
| `⌘E` | Open Snippet Editor. |
| `⌘,` | Open Preferences. |
| `⌥⌘V` | Undo last expansion (revert to abbreviation). |
| `⌘Q` | Quit. |
| `Esc` | Close popover or active modal. |

### Permissions
- **Accessibility** (required for text expansion). Without it, the app still works as a clipboard manager — show the permission banner in Preferences → Expansion and a one-time toast on first launch attempt to expand.
- **Input Monitoring** (macOS Catalina+). Same banner.
- **iCloud / CloudKit** (only if Sync turned on).

### Sync
- iCloud-backed, last-write-wins per record, 200-item history cap (configurable), snippets unbounded.
- Conflict resolution: a "Sync conflicts" subscreen in Preferences → Sync lists each pair with `Keep local`, `Keep remote`, `Keep both`.

### Empty / error states
- **Empty clipboard**: popover shows centered illustration (a single faded clipboard) + "Nothing copied yet. Try `⌘C` on anything." 13px muted.
- **No snippets**: editor center pane shows "Create your first snippet" CTA with the variable cheatsheet pre-rendered.
- **Sync paused** (offline): footer status pill flips to amber `Sync paused`.

### Animations
- Popover open: 120ms spring (`response: 0.32, dampingFraction: 0.78`), opacity + 4px y-translate.
- Row selection: instant (no animation).
- Toggle thumb: 180ms ease.
- Banner appear: 220ms ease-out, height + opacity.
- Editor save flicker: 400ms ease for the status pill color crossfade.
- Welcome step badge → green check: 300ms ease, scale `0.9 → 1`.

**No bounce, no decorative motion.** Match macOS system feel.

### Localization
- Strings are externalized in `.strings` files (or framework equivalent).
- Right-to-left mirroring is automatic via the layout direction — but **review every screen in RTL** during QA; specifically the chevrons in the Organized sidebar (must flip) and the popover anchor caret (must move to the right).
- Hebrew sample strings are in the prototype's `MenubarHebrew` component — they're sample copy, not the full localized set.

---

## State model (minimum)

```swift
// pseudo-Swift, illustrative only
struct ClipItem: Identifiable {
  let id: UUID
  let kind: Kind            // .text, .richText, .image, .file, .color, .link, .code
  let preview: String       // ellipsis-friendly
  let data: Data
  let sourceApp: BundleID?  // for "• Safari" subtitle
  let createdAt: Date
  var pinned: Bool
  var pinnedSlot: Int?      // 1...9
  var deleted: Bool         // tombstone for sync
}

struct Snippet: Identifiable {
  let id: UUID
  var title: String
  var abbreviation: String  // must start with . ; or /
  var trigger: Trigger      // .space, .tab, .enter, .anyChar, .punct, .manual
  var body: AttributedString // contains variable tokens
  var enabled: Bool
  var groupId: UUID?
  var allowedApps: Set<BundleID>?   // nil = all
  var deniedApps: Set<BundleID>
  var stats: Stats
}

struct Preferences {
  var theme: Theme            // .system, .light, .dark
  var density: Density        // .comfortable, .compact
  var globalHotkey: KeyCombo
  var historyLimit: Int       // default 200
  var soundFeedback: Bool
  var backspaceCancels: Bool
  var livePreview: Bool
  var excludedApps: Set<BundleID>
  var excludePasswordFields: Bool   // default true
  var syncEnabled: Bool
}
```

---

## Files in this bundle

```
design_handoff_clipflow/
├── README.md                           ← this file
├── CLAUDE_CODE_PROTOCOL.md             ← READ FIRST · how to drive Claude Code
├── screenshots/                        ← visual ground truth (14 PNGs)
│   ├── mb-simple-d.png
│   ├── mb-org-d.png
│   ├── mb-rtl-d.png
│   ├── mb-simple-l.png  (and -l for every screen below)
│   ├── snip-edit-d.png
│   ├── prefs-exp-d.png
│   ├── onboarding-d.png
│   └── about-d.png
└── design/
    ├── ClipFlow UI Review.html         ← live design canvas; open in a browser
    ├── design-canvas.jsx               ← canvas shell (pan/zoom/focus)
    └── components/
        ├── icons.jsx                   ← monochrome icon set (single source of truth)
        ├── menubar.jsx                 ← Popover, MenubarSimple, MenubarOrganized, MenubarHebrew, MenubarStage, ClipRow, SearchField, KBD, Section, FooterRow
        ├── editor.jsx                  ← Window chrome, SnippetEditor, Toggle, Select, Input, VarChip, Field, InspectorBlock, SidebarItem, ToolbarBtn
        ├── settings.jsx                ← SettingsExpansion, Welcome, ClipFlowMark (logo), Banner, Slider, SettingsTab, Step
        └── about.jsx                   ← About window
```

**Before asking Claude Code to write any code, read `CLAUDE_CODE_PROTOCOL.md`.** It contains the step-by-step protocol that prevents the drift seen in the initial implementation attempt.

To preview locally:
```bash
cd design_handoff_clipflow/design
python3 -m http.server 8080
# open http://localhost:8080/ClipFlow%20UI%20Review.html
```

The HTML is a single self-contained file (React + Babel via unpkg, JetBrains Mono + Inter via Google Fonts). It's an offline-friendly design reference — no backend.

---

## Definition of done

A reasonable check that the implementation matches:

1. Side-by-side: open the prototype's `mb-simple-d` artboard next to your built popover at 1× zoom. Title weight, row height, glyph size, kbd chip styling should be visually indistinguishable.
2. Repeat for the Light variants — the **same** SwiftUI views should render correctly in both themes by binding to the `Theme` env value; no per-theme view code.
3. Hebrew QA: switch macOS to Hebrew (System Settings → General → Language) and verify mirroring on every screen.
4. Keyboard QA: drive every screen without a mouse. Popover navigable with arrows + numerics. Editor's variable chips reachable via Tab.
5. Accessibility: every interactive element has a label exposed to VoiceOver. Run `⌃⌥⌘+F5` and tab through.
6. Reduce-motion: when "Reduce motion" is on in System Settings → Accessibility → Display, disable spring animations (popover opens with instant fade).
7. Both Light and Dark menubar wallpapers (System → Wallpaper → light variant + dark variant): the template status icon inverts correctly.
