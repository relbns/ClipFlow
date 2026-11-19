import SwiftUI

/// Every color the design defines in OKLCH, the same in light and dark.
/// Values come from `design_handoff_clipflow/design/components/*.jsx`.
enum BrandPalette {
    // MARK: Accent
    static let accent = Color.oklch(0.60, 0.17, 272)
    static let accentLight = Color.oklch(0.74, 0.17, 280)
    static let accentDeep = Color.oklch(0.50, 0.19, 268)
    /// Accent used as text or a thin mark on dark surfaces: the abbreviation dot, the caret.
    static let accentText = Color.oklch(0.78, 0.14, 272)
    static let accentLink = Color.oklch(0.68, 0.17, 272)
    static let accentIcon = Color.oklch(0.85, 0.12, 272)
    static let sidebarActiveIcon = Color.hex(0xB8B1FF)
    /// The popover's selected row: rgba(120,116,255,.22).
    static let selectedRow = Color.hex(0x7874FF, alpha: 0.22)

    // MARK: Status
    static let warning = Color.oklch(0.70, 0.17, 60)
    static let warningIcon = Color.oklch(0.85, 0.15, 60)
    static let warningText = Color.oklch(0.70, 0.15, 60)
    static let success = Color.oklch(0.70, 0.17, 145)
    static let successText = Color.oklch(0.80, 0.14, 145)
    static let danger = Color.hex(0xFF7A73)

    // MARK: Controls
    static let primaryButton = Gradient(colors: [.oklch(0.65, 0.17, 272), .oklch(0.55, 0.19, 272)])
    static let primaryButtonBorder = Color.oklch(0.50, 0.19, 272)
    static let varChip = Color.oklch(0.62, 0.15, 272)
    static let varChipText = Color.oklch(0.86, 0.12, 272)
    static let stepActive = Gradient(colors: [.oklch(0.65, 0.17, 272), .oklch(0.50, 0.19, 272)])
    static let stepActiveGlow = Color.oklch(0.55, 0.19, 272, alpha: 0.6)
    static let stepActiveBorder = Color.hex(0x7B71FF, alpha: 0.30)

    // MARK: Organized mode categories
    enum Category {
        static let recent = Color.oklch(0.78, 0.14, 70)
        static let images = Color.oklch(0.74, 0.14, 200)
        static let links = Color.oklch(0.78, 0.14, 145)
        static let colors = Color.oklch(0.78, 0.12, 320)
        static let text = Color.oklch(0.78, 0.12, 30)
    }

    // MARK: Preferences tabs
    enum SettingsTab {
        static let general = Color.oklch(0.55, 0.03, 250)
        static let appearance = Color.oklch(0.65, 0.12, 30)
        static let expansion = Color.oklch(0.60, 0.17, 272)
        static let hotkeys = Color.oklch(0.55, 0.12, 145)
        static let sync = Color.oklch(0.60, 0.14, 220)
        static let privacy = Color.oklch(0.55, 0.12, 200)
        static let language = Color.oklch(0.60, 0.14, 320)
    }

    // MARK: About credits
    enum Credit {
        static let creator = Color.oklch(0.65, 0.17, 272)
        static let clipy = Color.oklch(0.70, 0.14, 145)
        static let flycut = Color.oklch(0.72, 0.14, 30)
    }

    // MARK: Brand surfaces
    static let heroTile = Gradient(colors: [.oklch(0.74, 0.17, 280), .oklch(0.50, 0.19, 268)])
    static let heroShadow = Color.oklch(0.45, 0.19, 270, alpha: 0.55)
    static let welcomePanel = Gradient(stops: [
        .init(color: .oklch(0.45, 0.15, 285), location: 0),
        .init(color: .oklch(0.25, 0.08, 280), location: 0.6),
        .init(color: .oklch(0.18, 0.04, 270), location: 1)
    ])

    // MARK: Brand mark
    static let markTile = Gradient(colors: [.oklch(0.32, 0.04, 280), .oklch(0.20, 0.03, 270)])
    static let markFront = Gradient(colors: [.oklch(0.74, 0.17, 280), .oklch(0.55, 0.19, 270)])
    static let markBack = Gradient(colors: [.oklch(0.66, 0.17, 280), .oklch(0.50, 0.18, 270)])

    // MARK: Window chrome
    enum TrafficLight {
        static let close = Color.hex(0xFF5F57)
        static let minimize = Color.hex(0xFEBC2E)
        static let zoom = Color.hex(0x28C840)
    }
}
