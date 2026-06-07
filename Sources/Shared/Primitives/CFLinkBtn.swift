import SwiftUI

/// Footer link button with icon
/// Spec: accent color, no underline, 6px padding
struct CFLinkBtn: View {
    @Environment(\.cfTheme) var theme

    var icon: AnyView? = nil
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    icon
                        .foregroundColor(theme.accent)
                }

                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(theme.accent)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack(spacing: 16) {
        CFLinkBtn(
            icon: AnyView(Image(systemName: "link")),
            label: "GitHub"
        ) {
            print("GitHub tapped")
        }

        CFLinkBtn(
            icon: AnyView(Image(systemName: "doc.text")),
            label: "Full Credits"
        ) {
            print("Credits tapped")
        }
    }
    .cfAutoTheme()
    .padding()
    .background(Color(white: 0.15))
}
