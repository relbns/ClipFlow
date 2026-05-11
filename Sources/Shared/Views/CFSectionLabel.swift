import SwiftUI

/// Section label component for sidebar headers
/// Uppercase label with optional action button (e.g., plus icon)
struct CFSectionLabel: View {
    let text: String
    let action: (() -> Void)?

    @Environment(\.cfTheme) var theme

    init(_ text: String, action: (() -> Void)? = nil) {
        self.text = text
        self.action = action
    }

    var body: some View {
        HStack {
            Text(text)
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.6)  // letter-spacing 0.06em ≈ 0.6pt
                .textCase(.uppercase)
                .foregroundColor(theme.textLabel)

            Spacer()

            if let action = action {
                Button(action: action) {
                    CFIcon(type: .plus, size: 12, stroke: 1.8)
                        .foregroundColor(theme.textSubtle)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(EdgeInsets(top: 6, leading: 14, bottom: 4, trailing: 14))
    }
}

// MARK: - Preview
#Preview("Section Labels - Dark") {
    VStack(spacing: 0) {
        Text("Snippet Editor Sidebar")
            .font(.headline)
            .padding(.bottom, 16)

        // With action
        CFSectionLabel("LIBRARY")

        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(height: 60)

        // With action
        CFSectionLabel("GROUPS") {
            print("Add group tapped")
        }

        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(height: 100)

        CFSectionLabel("FAVORITES")

        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(height: 60)
    }
    .frame(width: 230)
    .background(Color(red: 0.10, green: 0.10, blue: 0.12))
    .cfAutoTheme()
}

#Preview("Section Labels - Light") {
    VStack(spacing: 16) {
        CFSectionLabel("LIBRARY")
        CFSectionLabel("GROUPS") {
            print("Add tapped")
        }
        CFSectionLabel("RECENT")
    }
    .padding()
    .frame(width: 230)
    .background(Color(red: 0.93, green: 0.93, blue: 0.94))
    .cfAutoTheme()
}
