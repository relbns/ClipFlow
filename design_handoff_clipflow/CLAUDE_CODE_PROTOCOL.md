# How to get Claude Code to match this design exactly

Read this **before** asking Claude Code to implement anything. The biggest cause of drift is treating the README as the source of truth — it isn't. The HTML prototype is. Claude Code must look at the HTML and the screenshots while it builds, then compare its output against them.

## The protocol

Run this in a fresh Claude Code session inside your repo.

### Step 0 — Prime
Paste this verbatim:

> Read `design_handoff_clipflow/README.md` and `design_handoff_clipflow/CLAUDE_CODE_PROTOCOL.md` end-to-end. Then list every artboard ID in `design_handoff_clipflow/screenshots/`. Confirm you can see them as image files. Do not write any code yet.

If it can't enumerate the artboards, stop and re-share the folder.

### Step 1 — Build the Theme layer FIRST
> Implement `Theme.swift` (or the stack's equivalent) from the "Design Tokens" section of the README. Bind it as an EnvironmentObject. Both `.dark` and `.light` must compile. Do not implement any screens yet. When done, render a tiny test view that shows one swatch for each token and screenshot it next to `design_handoff_clipflow/screenshots/mb-simple-d.png` to sanity-check the surface and text colors. Wait for my approval.

This single step prevents ~60% of drift. Most mismatches above happened because Claude Code used SwiftUI default colors (`.primary`, `.secondary`, `.accentColor`) instead of the prototype's exact tokens.

### Step 2 — Build the primitive component library
> Now implement these primitives, each as its own SwiftUI view. Use ONLY the Theme tokens. After each one, screenshot it and place the screenshot next to the matching crop from `design_handoff_clipflow/screenshots/snip-edit-d.png`:
>
> 1. `KBDChip` — see KBD in `design/components/menubar.jsx`
> 2. `IconRow` — clipboard row layout (icon tile + title + subtitle + trailing slot)
> 3. `Toggle` — exact dimensions 32×18, 14×14 thumb. Match the prototype's `Toggle` in `design/components/editor.jsx`
> 4. `VarChip` — the variable token chip in the editor
> 5. `WindowChrome` — traffic lights + 38px titlebar
> 6. `PopoverChrome` — the menubar dropdown shell with backdrop blur

Make Claude Code stop and show you each primitive before moving on. **This is the part it skipped in the screenshots you saw** — it built screens directly using default SwiftUI controls.

### Step 3 — Build screens, ONE at a time, in this order
For each screen, the prompt template is:

> Implement `<ScreenName>` to match `design_handoff_clipflow/screenshots/<artboard-id>.png` PIXEL-PERFECTLY.
>
> Open both `design_handoff_clipflow/design/ClipFlow UI Review.html` (HTML source) and `screenshots/<artboard-id>.png` (visual reference). Extract exact values (padding, font sizes, colors) from the JSX by reading `design/components/<file>.jsx`. Do not invent any styling — use only Theme tokens and the primitives from Step 2.
>
> After implementing, run the app, screenshot the same screen, save it as `__verify/<artboard-id>-actual.png`, and place it next to the reference. Tell me every visible difference. Do not move on until I sign off.

Build order (matches the dependency graph):
1. **mb-simple-d** — the menubar Simple mode. Easiest, exercises primitives.
2. **mb-simple-l** — light variant. If theme is wired right, this is mostly free.
3. **mb-org-d** + **mb-org-l** — adds pinned rows, category tiles, segmented mode toggle.
4. **mb-rtl-d** — flip layout direction. Verify chevrons mirror.
5. **prefs-exp-d** + **prefs-exp-l** — Preferences shell + Expansion tab. Establishes tab strip.
6. **about-d** + **about-l** — small, mostly static. Logo asset goes here.
7. **onboarding-d** + **onboarding-l** — gradient panel + step list.
8. **snip-edit-d** + **snip-edit-l** — the biggest screen, do last after primitives are battle-tested.

### Step 4 — Behavior wiring
Only after every screen passes visual review:

> Now wire up the behaviors from README sections "Cross-cutting behaviors" and the per-surface "Behavior" subsections. Do not change any layout, color, or typography. If a behavior requires a new visual state I didn't already design (e.g. error state), stop and ask before inventing it.

## Why the screenshots you shared went off-spec

| Surface | What you got | What the design specifies | Likely cause |
|---|---|---|---|
| Menubar | One empty "Recent" category; two identical "Current Time" snippets | 10 mixed-type recent clips, 2 pinned items, 5 colored category tiles, footer with full menu | No real data wired; Claude Code used placeholder data instead of the prototype's sample data which is the spec |
| Preferences | "ClipFlow + tagline + logo" header inside body | Tab strip only — no in-body branding (that lives in About) | Treated About branding as global chrome |
| Preferences | Native-looking large toggles | Custom 32×18 toggle with 14×14 thumb | Used `Toggle()` default; ignored the custom primitive spec |
| Snippet Editor | Two side-by-side panels: `Groups` and `Snippets` | One sidebar with nested groups → snippets, center editor with content, right inspector | Wrong IA; missed the 3-pane spec completely |
| Snippet Editor | Empty right pane "Select a snippet to edit" | Always shows a snippet (default to first) with full editor + variable chips + inspector | Empty state shouldn't exist on launch when there's data |
| Snippet Editor | No variable chips, no trigger row, no inspector | All three are central to the editor | Spec sections skipped |

## Reference: every artboard

These PNGs are the visual ground truth. The HTML is the styling/values ground truth. Both are in this folder.

| ID | Surface | Theme | File |
|---|---|---|---|
| `mb-simple-d` | MenuBar — Simple | Dark | screenshots/mb-simple-d.png |
| `mb-org-d` | MenuBar — Organized | Dark | screenshots/mb-org-d.png |
| `mb-rtl-d` | MenuBar — Hebrew RTL | Dark | screenshots/mb-rtl-d.png |
| `mb-simple-l` | MenuBar — Simple | Light | screenshots/mb-simple-l.png |
| `mb-org-l` | MenuBar — Organized | Light | screenshots/mb-org-l.png |
| `mb-rtl-l` | MenuBar — Hebrew RTL | Light | screenshots/mb-rtl-l.png |
| `snip-edit-d` | Snippet Editor | Dark | screenshots/snip-edit-d.png |
| `snip-edit-l` | Snippet Editor | Light | screenshots/snip-edit-l.png |
| `prefs-exp-d` | Preferences (Expansion tab) | Dark | screenshots/prefs-exp-d.png |
| `prefs-exp-l` | Preferences (Expansion tab) | Light | screenshots/prefs-exp-l.png |
| `onboarding-d` | Welcome / Onboarding | Dark | screenshots/onboarding-d.png |
| `onboarding-l` | Welcome / Onboarding | Light | screenshots/onboarding-l.png |
| `about-d` | About ClipFlow | Dark | screenshots/about-d.png |
| `about-l` | About ClipFlow | Light | screenshots/about-l.png |

## Anti-patterns to call out in your prompts

When the model is about to drift, these are the warning phrases to push back on:

| If Claude Code says… | Reply with… |
|---|---|
| "I'll use SwiftUI's `Toggle`" | "No — implement the custom 32×18 toggle from `design/components/editor.jsx` line where `const Toggle` is defined." |
| "I'll use the system accent" | "No — accent is `oklch(0.60 0.17 272)` from `Theme.brand`. Bind to that." |
| "I added a settings header with the app name" | "Remove it — the Preferences window has no in-body branding. Only the About window does." |
| "I split Groups and Snippets into two panels" | "No — see `screenshots/snip-edit-d.png`. There is ONE 230px sidebar with collapsible groups. The center pane is always the editor for the selected snippet." |
| "I'll use SF Symbols for everything" | "Use SF Symbols only where listed in README → Iconography. For others, the source is `design/components/icons.jsx`." |
| "I added some example/placeholder data" | "The sample data IN the prototype's screens IS the spec. Match every visible row including type, subtitle text and kbd value." |
| "I made the corners more rounded for a modern look" | "Use exactly the radii in README → Spacing & Density. Don't editorialize." |

## Verification checklist (run before any PR)

Open the prototype's matching screenshot side-by-side with your build at 1× zoom. For each artboard:

- [ ] Window/popover **width** matches within 4px
- [ ] **Row heights** match within 2px
- [ ] **Glyph sizes** match (≤2px difference)
- [ ] **Kbd chip** dimensions, font, and padding match
- [ ] **Selected-row** background is `color-mix(brand 22%, transparent)`, NOT a system selection color
- [ ] **Toggle** is 32×18 with a 14×14 thumb (NOT system default)
- [ ] **Section caps** are uppercase, 10.5px, 600 weight, .06em letter-spacing
- [ ] **Numeric kbd chips** appear on rows 1–10 in Simple mode
- [ ] **Backdrop blur** is applied to popover (20–28px)
- [ ] **Hebrew** mode: chevrons, search icon, kbd chips all on correct side
- [ ] Switch macOS to Light theme — surfaces, strokes, shadows all rebind correctly

When ALL boxes pass for ALL 14 artboards, the implementation matches the design.
