import SwiftUI

/// Footer row button component for MenuBar popover
/// Full-width button with icon, label, and optional keyboard shortcut
struct CFFooterRowBtn: View {
    let icon: CFIcon.IconType
    let label: String
    let kbd: String?
    let danger: Bool
    let action: () -> Void

    @Environment(\.cfTheme) var theme

    init(
        icon: CFIcon.IconType,
        label: String,
        kbd: String? = nil,
        danger: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.label = label
        self.kbd = kbd
        self.danger = danger
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Icon
                CFIcon(type: icon, size: 14, stroke: 1.8)
                    .foregroundColor(danger ? Color(red: 1.0, green: 0.48, blue: 0.45) : theme.textMuted)
                    .frame(width: 16, alignment: .center)

                // Label
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(danger ? Color(red: 1.0, green: 0.48, blue: 0.45) : theme.text)

                Spacer()

                // Keyboard shortcut badge (optional)
                if let kbd = kbd {
                    CFKBD(text: kbd, dim: true)
                }
            }
            .frame(height: 28)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview("Footer Row Buttons - Dark") {
    VStack(spacing: 0) {
        Text("MenuBar Footer")
            .font(.headline)
            .padding()

        VStack(spacing: 0) {
            Divider()

            CFFooterRowBtn(icon: .sparkles, label: "Snippet Editor…", kbd: "⌘E") {
                print("Open editor")
            }

            CFFooterRowBtn(icon: .gear, label: "Preferences…", kbd: "⌘,") {
                print("Open preferences")
            }

            Divider()

            CFFooterRowBtn(icon: .trash, label: "Clear history") {
                print("Clear history")
            }

            CFFooterRowBtn(icon: .power, label: "Quit ClipFlow", kbd: "⌘Q", danger: true) {
                print("Quit")
            }
        }
        .background(theme.fill1)

        Text("↑ Danger variant (Quit)")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.top, 8)
    }
    .frame(width: 340)
    .background(Color(red: 0.11, green: 0.11, blue: 0.13))
    .cfAutoTheme()
}

#Preview("Footer Row Buttons - Light") {
    VStack(spacing: 0) {
        CFFooterRowBtn(icon: .sparkles, label: "Snippet Editor…", kbd: "⌘E") {
            print("Editor")
        }
        CFFooterRowBtn(icon: .gear, label: "Preferences…", kbd: "⌘,") {
            print("Preferences")
        }
        Divider()
        CFFooterRowBtn(icon: .trash, label: "Clear history") {
            print("Clear")
        }
        CFFooterRowBtn(icon: .power, label: "Quit", danger: true) {
            print("Quit")
        }
    }
    .frame(width: 340)
    .background(Color(red: 0.96, green: 0.96, blue: 0.97))
    .cfAutoTheme()
}
