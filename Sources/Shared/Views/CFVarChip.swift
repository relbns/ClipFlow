import SwiftUI

/// Variable token chip component for snippet editor
/// Matches the VarChip component from design/components/editor.jsx
///
/// Specs:
/// - Padding: 2px 8px
/// - Border radius: 4
/// - Background: accent 30% opacity
/// - Color: light accent (lighter version of main accent)
/// - Font: monospace, 12pt
/// - Border: 1px accent 35% opacity
struct CFVarChip: View {
    @Environment(\.cfTheme) var theme

    let text: String
    let icon: AnyView?

    init(_ text: String) {
        self.text = text
        self.icon = nil
    }

    init<Icon: View>(_ text: String, icon: Icon) {
        self.text = text
        self.icon = AnyView(icon)
    }

    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                icon
            }
            Text(text)
                .font(.system(size: 12, design: .monospaced))
        }
        .foregroundColor(lightAccent)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(theme.accentMix(percent: 30))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(theme.accentMix(percent: 35), lineWidth: 1)
        )
        .cornerRadius(4)
    }

    // Light version of accent for chip text
    // oklch(.86 .12 272) - lighter, less saturated version
    private var lightAccent: Color {
        // Approximate oklch(.86 .12 272)
        Color(red: 0.82, green: 0.80, blue: 1.0)
    }
}

// MARK: - Preview
#if DEBUG
struct CFVarChip_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack(spacing: 30) {
                Text("Variable Chip Component")
                    .font(.title2)
                    .bold()

                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        CFVarChip("{date}")
                        CFVarChip("{time}")
                        CFVarChip("{clipboard}")
                        CFVarChip("{cursor}")
                    }

                    HStack(spacing: 8) {
                        CFVarChip("{date:yyyy-MM-dd}")
                        CFVarChip("{prompt:Name}")
                    }
                }

                // In context (snippet editor)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Insert variable:")
                        .font(.system(size: 11.5))
                        .foregroundColor(theme.textMuted)

                    HStack(spacing: 6) {
                        CFVarChip("{date}")
                        CFVarChip("{time}")
                        CFVarChip("{clipboard}")
                        CFVarChip("{cursor}")
                        CFVarChip("{prompt:Name}")
                    }

                    Text("{date:yyyy-MM-dd} for custom format")
                        .font(.system(size: 11))
                        .foregroundColor(theme.textFaint)
                }
                .padding()
                .background(theme.surfaceDeep)
                .cornerRadius(8)
            }
            .padding(40)
            .frame(width: 600, height: 400)
            .background(theme.surface)
            .cfAutoTheme()
            .previewDisplayName("VarChip - Light")

            VStack(spacing: 30) {
                Text("Variable Chip Component")
                    .font(.title2)
                    .bold()

                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        CFVarChip("{date}")
                        CFVarChip("{time}")
                        CFVarChip("{clipboard}")
                        CFVarChip("{cursor}")
                    }

                    HStack(spacing: 8) {
                        CFVarChip("{date:yyyy-MM-dd}")
                        CFVarChip("{prompt:Name}")
                    }
                }
            }
            .padding(40)
            .frame(width: 600, height: 400)
            .background(theme.surface)
            .cfAutoTheme()
            .preferredColorScheme(.dark)
            .previewDisplayName("VarChip - Dark")
        }
    }

    private static var theme: CFTheme { .dark }
}
#endif
