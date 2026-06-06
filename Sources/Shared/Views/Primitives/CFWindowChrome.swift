import SwiftUI

/// Window titlebar chrome component
/// Matches the Window component titlebar from design/components/editor.jsx
///
/// Specs:
/// - Height: 38px
/// - Padding: 0 12px
/// - Traffic lights: 12×12, gap 8
/// - Background: titlebar-bg gradient
/// - Border bottom: 1px stroke-soft
/// - Centered title: 13pt, text-mid, weight 500
/// - Toolbar on trailing edge
struct CFWindowChrome<Toolbar: View>: View {
    @Environment(\.cfTheme) var theme

    let title: String
    let toolbar: Toolbar

    init(title: String, @ViewBuilder toolbar: () -> Toolbar) {
        self.title = title
        self.toolbar = toolbar()
    }

    var body: some View {
        ZStack {
            // Background
            theme.titlebarBg

            HStack(spacing: 10) {
                // Traffic lights
                trafficLights

                Spacer()

                // Toolbar
                toolbar
            }
            .padding(.horizontal, 12)

            // Centered title
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.textMid)
        }
        .frame(height: 38)
        .overlay(
            Rectangle()
                .fill(theme.strokeSoft)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var trafficLights: some View {
        HStack(spacing: 8) {
            // Red
            Circle()
                .fill(Color(red: 1, green: 0.37, blue: 0.34))
                .frame(width: 12, height: 12)
                .shadow(color: .black.opacity(0.15), radius: 0, x: 0, y: 0)
                .overlay(
                    Circle()
                        .strokeBorder(theme.shadowSoft, lineWidth: 0.5)
                )

            // Yellow
            Circle()
                .fill(Color(red: 0.99, green: 0.74, blue: 0.18))
                .frame(width: 12, height: 12)
                .shadow(color: .black.opacity(0.15), radius: 0, x: 0, y: 0)
                .overlay(
                    Circle()
                        .strokeBorder(theme.shadowSoft, lineWidth: 0.5)
                )

            // Green
            Circle()
                .fill(Color(red: 0.16, green: 0.78, blue: 0.25))
                .frame(width: 12, height: 12)
                .shadow(color: .black.opacity(0.15), radius: 0, x: 0, y: 0)
                .overlay(
                    Circle()
                        .strokeBorder(theme.shadowSoft, lineWidth: 0.5)
                )
        }
    }
}

// Convenience init without toolbar
extension CFWindowChrome where Toolbar == EmptyView {
    init(title: String) {
        self.title = title
        self.toolbar = EmptyView()
    }
}

// MARK: - Preview
#if DEBUG
struct CFWindowChrome_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack(spacing: 0) {
                CFWindowChrome(title: "Snippet Editor — Email signature") {
                    HStack(spacing: 6) {
                        Text("+ New")
                            .font(.system(size: 12))
                        Text("Duplicate")
                            .font(.system(size: 12))
                    }
                }

                Rectangle()
                    .fill(theme.surface)
                    .frame(height: 300)
            }
            .frame(width: 800)
            .cfAutoTheme()
            .previewDisplayName("Window Chrome - Light")

            VStack(spacing: 0) {
                CFWindowChrome(title: "ClipFlow Settings")

                Rectangle()
                    .fill(theme.surface)
                    .frame(height: 300)
            }
            .frame(width: 760)
            .cfAutoTheme()
            .preferredColorScheme(.dark)
            .previewDisplayName("Window Chrome - Dark")
        }
    }

    private static var theme: CFTheme { .dark }
}
#endif
