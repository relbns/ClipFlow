import SwiftUI

/// Keyboard shortcut chip component
/// Matches the KBD component from design/components/menubar.jsx
///
/// Specs:
/// - Font: Monospace (SF Mono/Menlo), 11pt, weight 500
/// - Padding: 2px 5px
/// - Min width: 16
/// - Border radius: 4
/// - Border: 1px stroke
/// - Shadow: inset 0 -1px 0 shadow-strong
/// - Two states: dim (subtle) and normal (mid)
struct CFKBDChip: View {
    @Environment(\.cfTheme) var theme

    let text: String
    let dim: Bool

    init(_ text: String, dim: Bool = false) {
        self.text = text
        self.dim = dim
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(dim ? theme.textSubtle : theme.textMid)
            .lineLimit(1)
            .padding(.vertical, 2)
            .padding(.horizontal, 5)
            .frame(minWidth: 16)
            .background(dim ? theme.fillSoft : theme.fill2)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(theme.stroke, lineWidth: 1)
            )
            .overlay(
                // Inner bottom shadow
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(theme.shadowStrong)
                        .frame(height: 1)
                        .padding(.horizontal, 1)
                }
                .allowsHitTesting(false)
            )
            .cornerRadius(4)
            .multilineTextAlignment(.center)
    }
}

// MARK: - Preview
#if DEBUG
struct CFKBDChip_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack(spacing: 20) {
                Text("KBD Chip Variants")
                    .font(.title2)
                    .bold()

                HStack(spacing: 16) {
                    VStack(spacing: 8) {
                        CFKBDChip("⌘F")
                        Text("Normal")
                            .font(.caption2)
                    }

                    VStack(spacing: 8) {
                        CFKBDChip("⌘F", dim: true)
                        Text("Dim")
                            .font(.caption2)
                    }

                    VStack(spacing: 8) {
                        CFKBDChip("1")
                        Text("Number")
                            .font(.caption2)
                    }

                    VStack(spacing: 8) {
                        CFKBDChip("⌘,")
                        Text("Combo")
                            .font(.caption2)
                    }
                }

                // In context
                HStack {
                    Text("Search")
                        .foregroundColor(theme.text)
                    Spacer()
                    CFKBDChip("⌘F", dim: true)
                }
                .padding()
                .background(theme.surfaceDeep)
                .cornerRadius(8)
            }
            .padding(40)
            .frame(width: 500, height: 400)
            .background(theme.surface)
            .cfAutoTheme()
            .previewDisplayName("KBD Chips - Light")

            VStack(spacing: 20) {
                Text("KBD Chip Variants")
                    .font(.title2)
                    .bold()

                HStack(spacing: 16) {
                    VStack(spacing: 8) {
                        CFKBDChip("⌘F")
                        Text("Normal")
                            .font(.caption2)
                    }

                    VStack(spacing: 8) {
                        CFKBDChip("⌘F", dim: true)
                        Text("Dim")
                            .font(.caption2)
                    }

                    VStack(spacing: 8) {
                        CFKBDChip("1")
                        Text("Number")
                            .font(.caption2)
                    }
                }
            }
            .padding(40)
            .frame(width: 500, height: 400)
            .background(theme.surface)
            .cfAutoTheme()
            .preferredColorScheme(.dark)
            .previewDisplayName("KBD Chips - Dark")
        }
    }

    private static var theme: CFTheme { .dark }
}
#endif
