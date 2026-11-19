import SwiftUI

/// Popover shell component for menubar dropdown
/// Matches the Popover component from design/components/menubar.jsx
///
/// Specs:
/// - Border radius: 12
/// - Background: popover-bg gradient
/// - Backdrop blur: 28px, saturate 160% (handled by NSVisualEffectView in NSPopover)
/// - Shadow: popover-shadow
/// - Default width: 340
struct CFPopoverChrome<Content: View>: View {
    @Environment(\.cfTheme) var theme

    let width: CGFloat
    let content: Content

    init(width: CGFloat = 340, @ViewBuilder content: () -> Content) {
        self.width = width
        self.content = content()
    }

    var body: some View {
        content
            .frame(width: width)
            .background(theme.popoverBg)
            .cornerRadius(12)
            .shadow(
                color: theme.popoverShadow.color,
                radius: theme.popoverShadow.radius,
                x: theme.popoverShadow.x,
                y: theme.popoverShadow.y
            )
            .overlay(
                // Outer stroke
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        theme.colorScheme == .dark
                            ? Color.white.opacity(0.10)
                            : Color.black.opacity(0.10),
                        lineWidth: 0.5
                    )
            )
            .overlay(
                // Inner highlight (top edge)
                VStack {
                    Rectangle()
                        .fill(
                            theme.colorScheme == .dark
                                ? Color.white.opacity(0.06)
                                : Color.white.opacity(0.5)
                        )
                        .frame(height: 1)
                    Spacer()
                }
                .cornerRadius(12)
                .allowsHitTesting(false)
            )
    }
}

// MARK: - Preview
#if DEBUG
struct CFPopoverChrome_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ZStack {
                // Background to show blur effect simulation
                LinearGradient(
                    colors: [BrandPalette.accent.opacity(0.3), BrandPalette.Category.colors.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                CFPopoverChrome(width: 340) {
                    VStack(spacing: 0) {
                        // Search field
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 13))
                                .foregroundColor(theme.textSubtle)
                            TextField("Search clipboard…", text: .constant(""))
                                .textFieldStyle(.plain)
                            CFKBDChip("⌘F", dim: true)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(theme.inputBg)
                        .cornerRadius(7)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .strokeBorder(theme.stroke, lineWidth: 1)
                        )
                        .padding(8)

                        // Section
                        HStack {
                            Text("RECENT CLIPS")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundColor(theme.textLabel)
                                .textCase(.uppercase)
                                .kerning(0.6)
                            Spacer()
                            Text("14 items")
                                .font(.system(size: 10.5))
                                .foregroundColor(theme.textSubtle)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)

                        // Sample rows
                        VStack(spacing: 0) {
                            CFIconRow(
                                icon: AnyView(Image(systemName: "link").font(.system(size: 14))),
                                title: "github.com/relbns/ClipFlow",
                                subtitle: "copied 12s ago • Safari",
                                kbd: "1",
                                active: true
                            )
                            .padding(.horizontal, 6)

                            CFIconRow(
                                icon: AnyView(Image(systemName: "text.alignleft").font(.system(size: 14))),
                                title: "Thanks for the quick turnaround",
                                subtitle: "copied 2m ago • Mail",
                                kbd: "2"
                            )
                            .padding(.horizontal, 6)
                        }
                        .padding(.bottom, 8)
                    }
                }
            }
            .frame(width: 600, height: 500)
            .cfAutoTheme()
            .previewDisplayName("Popover Chrome - Light")

            ZStack {
                LinearGradient(
                    colors: [BrandPalette.accent.opacity(0.3), BrandPalette.Category.colors.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                CFPopoverChrome(width: 340) {
                    VStack(spacing: 12) {
                        Text("Popover Content")
                            .font(.title3)
                            .foregroundColor(theme.textStrong)

                        Text("The backdrop blur and saturation\nare handled by NSPopover's\nNSVisualEffectView")
                            .font(.system(size: 12))
                            .foregroundColor(theme.textMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                }
            }
            .frame(width: 600, height: 500)
            .cfAutoTheme()
            .preferredColorScheme(.dark)
            .previewDisplayName("Popover Chrome - Dark")
        }
    }

    private static var theme: CFTheme { .dark }
}
#endif
