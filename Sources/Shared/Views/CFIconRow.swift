import SwiftUI

/// Icon row layout component for clipboard items
/// Matches the ClipRow component from design/components/menubar.jsx
///
/// Specs:
/// - Padding: 6px 10px
/// - Margin: 0 6px (handled by parent)
/// - Border radius: 6
/// - Gap: 10
/// - Active background: accent 22% opacity
/// - Icon tile: 26×26, radius 5, fill-1 background
/// - Title: 13pt, text-strong, weight 500 if active else 400
/// - Subtitle: 11pt, text-label
struct CFIconRow: View {
    @Environment(\.cfTheme) var theme
    @Environment(\.layoutDirection) var layoutDirection

    let icon: AnyView
    let title: String
    let subtitle: String?
    let kbd: String?
    let active: Bool
    let customTrailing: AnyView?

    init(
        icon: AnyView,
        title: String,
        subtitle: String? = nil,
        kbd: String? = nil,
        active: Bool = false,
        customTrailing: AnyView? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.kbd = kbd
        self.active = active
        self.customTrailing = customTrailing
    }

    // Convenience init for simple icon
    init<Icon: View>(
        icon: Icon,
        title: String,
        subtitle: String? = nil,
        kbd: String? = nil,
        active: Bool = false
    ) {
        self.icon = AnyView(icon)
        self.title = title
        self.subtitle = subtitle
        self.kbd = kbd
        self.active = active
        self.customTrailing = nil
    }

    var body: some View {
        HStack(spacing: 10) {
            // Icon tile
            iconTile

            // Title + Subtitle
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: active ? .medium : .regular))
                    .foregroundColor(theme.textStrong)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(theme.textLabel)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Trailing: custom or KBD chip
            if let customTrailing = customTrailing {
                customTrailing
            } else if let kbd = kbd {
                CFKBDChip(kbd, dim: !active)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            active
                ? theme.accentMix(percent: 22)
                : Color.clear
        )
        .cornerRadius(6)
    }

    private var iconTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(theme.fill1)

            icon
                .foregroundColor(theme.textMid)
        }
        .frame(width: 26, height: 26)
        .clipped()
    }
}

// MARK: - Preview
#if DEBUG
struct CFIconRow_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack(spacing: 0) {
                Text("Icon Row Variants")
                    .font(.title2)
                    .bold()
                    .padding()

                VStack(spacing: 0) {
                    // Link
                    CFIconRow(
                        icon: AnyView(
                            Image(systemName: "link")
                                .font(.system(size: 14))
                        ),
                        title: "github.com/relbns/ClipFlow",
                        subtitle: "copied 12s ago • Safari",
                        kbd: "1",
                        active: true
                    )
                    .padding(.horizontal, 6)

                    // Text
                    CFIconRow(
                        icon: AnyView(
                            Image(systemName: "text.alignleft")
                                .font(.system(size: 14))
                        ),
                        title: "Thanks for the quick turnaround — I'll review the…",
                        subtitle: "copied 2m ago • Mail",
                        kbd: "2"
                    )
                    .padding(.horizontal, 6)

                    // Color
                    CFIconRow(
                        icon: AnyView(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.hex(0xFF5733))
                                .frame(width: 16, height: 16)
                                .shadow(color: .black.opacity(0.15), radius: 0, x: 0, y: 0)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .strokeBorder(Color.black.opacity(0.1), lineWidth: 0.5)
                                )
                        ),
                        title: "#FF5733",
                        subtitle: "hex color • Figma",
                        kbd: "3"
                    )
                    .padding(.horizontal, 6)

                    // Code
                    CFIconRow(
                        icon: AnyView(
                            Image(systemName: "curlybraces")
                                .font(.system(size: 14))
                        ),
                        title: "const result = await fetch(url)",
                        subtitle: "3 lines • Xcode",
                        kbd: "4"
                    )
                    .padding(.horizontal, 6)
                }
                .padding(.vertical, 4)
            }
            .frame(width: 340)
            .background(theme.surface)
            .cfAutoTheme()
            .previewDisplayName("Icon Rows - Light")

            VStack(spacing: 0) {
                Text("Icon Row Variants")
                    .font(.title2)
                    .bold()
                    .padding()

                VStack(spacing: 0) {
                    CFIconRow(
                        icon: AnyView(
                            Image(systemName: "link")
                                .font(.system(size: 14))
                        ),
                        title: "github.com/relbns/ClipFlow",
                        subtitle: "copied 12s ago • Safari",
                        kbd: "1",
                        active: true
                    )
                    .padding(.horizontal, 6)

                    CFIconRow(
                        icon: AnyView(
                            Image(systemName: "text.alignleft")
                                .font(.system(size: 14))
                        ),
                        title: "Thanks for the quick turnaround",
                        subtitle: "copied 2m ago • Mail",
                        kbd: "2"
                    )
                    .padding(.horizontal, 6)
                }
                .padding(.vertical, 4)
            }
            .frame(width: 340)
            .background(theme.surface)
            .cfAutoTheme()
            .preferredColorScheme(.dark)
            .previewDisplayName("Icon Rows - Dark")
        }
    }

    private static var theme: CFTheme { .dark }
}
#endif
