import SwiftUI

// MARK: - Toolbar Button (for window toolbars)
struct CFToolbarBtn: View {
    var icon: AnyView? = nil
    let label: String
    var primary: Bool = false
    var action: (() -> Void)? = nil

    @Environment(\.cfTheme) var theme

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 6) {
                if let icon = icon {
                    icon
                        .frame(width: 12, height: 12)
                }
                Text(label)
                    .font(.system(size: 12))
            }
            .foregroundColor(primary ? .white : theme.textStrong)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(
                primary
                    ? LinearGradient(
                        colors: [
                            Color(red: 0.65, green: 0.17, blue: 0.72, opacity: 1.0),
                            Color(red: 0.55, green: 0.19, blue: 0.72, opacity: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    : theme.btnBg
            )
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        primary
                            ? Color(red: 0.5, green: 0.19, blue: 0.72, opacity: 1.0)
                            : theme.fill2,
                        lineWidth: 1
                    )
            )
            .shadow(
                color: theme.btnShadow.color,
                radius: theme.btnShadow.radius,
                x: theme.btnShadow.x,
                y: theme.btnShadow.y
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Icon Button (compact, icon-only)
struct CFIconBtn: View {
    let icon: AnyView
    var size: CGFloat = 22
    var action: (() -> Void)? = nil

    @Environment(\.cfTheme) var theme

    var body: some View {
        Button(action: { action?() }) {
            icon
                .frame(width: size, height: size)
                .background(Color.clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainHoverButtonStyle())
    }
}

// MARK: - Link Button (text-only, accent color)
struct CFLinkBtn: View {
    var icon: AnyView? = nil
    let label: String
    var action: (() -> Void)? = nil

    @Environment(\.cfTheme) var theme

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 6) {
                if let icon = icon {
                    icon
                        .frame(width: 13, height: 13)
                }
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(Color(red: 0.68, green: 0.17, blue: 0.72, opacity: 1.0))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(PlainHoverButtonStyle())
    }
}

// MARK: - Danger Button (for destructive actions)
struct CFDangerBtn: View {
    let label: String
    var action: (() -> Void)? = nil

    @Environment(\.cfTheme) var theme

    var body: some View {
        Button(action: { action?() }) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Color(red: 1.0, green: 0.48, blue: 0.45, opacity: 1.0))
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(theme.btnBg)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(theme.fill2, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Group Row Button (for organized mode categories)
struct CFGroupRow: View {
    let icon: AnyView
    let label: String
    let count: Int
    let accent: Color
    var action: (() -> Void)? = nil

    @Environment(\.cfTheme) var theme

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 10) {
                // Icon badge
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(accent.opacity(0.22))
                        .frame(width: 22, height: 22)

                    icon
                        .foregroundColor(accent)
                        .frame(width: 13, height: 13)
                }

                // Label
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Count badge
                CFCountBadge(count: count)

                // Chevron
                CFIcon(type: .chevron, size: 14, stroke: 1.8)
                    .foregroundColor(theme.textFaint)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(PlainHoverButtonStyle())
    }
}

// MARK: - Hover Button Style
struct PlainHoverButtonStyle: ButtonStyle {
    @Environment(\.cfTheme) var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed
                    ? theme.fill2
                    : Color.clear
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview
#if DEBUG
struct CFButtons_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ButtonsShowcase()
                .cfAutoTheme()
                .previewDisplayName("Light")

            ButtonsShowcase()
                .cfAutoTheme()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark")
        }
    }

    struct ButtonsShowcase: View {
        @Environment(\.cfTheme) var theme

        var body: some View {
            VStack(spacing: 24) {
                Text("ClipFlow Buttons")
                    .font(.title2)
                    .bold()
                    .foregroundColor(theme.textStrong)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Toolbar Buttons")
                        .font(.headline)
                        .foregroundColor(theme.text)

                    HStack(spacing: 8) {
                        CFToolbarBtn(
                            icon: AnyView(CFIcon(type: .plus, size: 12)),
                            label: "New"
                        )
                        CFToolbarBtn(label: "Duplicate")
                        CFToolbarBtn(
                            icon: AnyView(CFIcon(type: .cloud, size: 12)),
                            label: "Synced"
                        )
                        CFToolbarBtn(label: "Open System Settings", primary: true)
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Icon Buttons")
                        .font(.headline)
                        .foregroundColor(theme.text)

                    HStack(spacing: 10) {
                        CFIconBtn(icon: AnyView(CFIcon(type: .gear, size: 14)))
                        CFIconBtn(icon: AnyView(CFIcon(type: .trash, size: 14)))
                        CFIconBtn(icon: AnyView(CFIcon(type: .plus, size: 14)))
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Link Buttons")
                        .font(.headline)
                        .foregroundColor(theme.text)

                    HStack(spacing: 12) {
                        CFLinkBtn(
                            icon: AnyView(CFIcon(type: .link, size: 13)),
                            label: "GitHub"
                        )
                        CFLinkBtn(
                            icon: AnyView(CFIcon(type: .text, size: 13)),
                            label: "Full Credits"
                        )
                        CFLinkBtn(
                            icon: AnyView(CFIcon(type: .gear, size: 13)),
                            label: "License"
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Danger Button")
                        .font(.headline)
                        .foregroundColor(theme.text)

                    CFDangerBtn(label: "Delete All History")
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Group Rows")
                        .font(.headline)
                        .foregroundColor(theme.text)

                    CFGroupRow(
                        icon: AnyView(CFIcon(type: .clock, size: 13)),
                        label: "Recent",
                        count: 14,
                        accent: Color(red: 0.78, green: 0.14, blue: 0.70)
                    )

                    CFGroupRow(
                        icon: AnyView(CFIcon(type: .image, size: 13)),
                        label: "Images",
                        count: 3,
                        accent: Color(red: 0.74, green: 0.14, blue: 0.60)
                    )

                    CFGroupRow(
                        icon: AnyView(CFIcon(type: .link, size: 13)),
                        label: "Links",
                        count: 6,
                        accent: Color(red: 0.78, green: 0.14, blue: 0.50)
                    )
                }
            }
            .padding(30)
            .frame(width: 600, height: 800)
            .background(theme.surfaceDeep)
        }
    }
}
#endif
