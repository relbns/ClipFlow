import SwiftUI
import KeyboardShortcuts

struct HotkeySettingsView: View {
    var body: some View {
        Form {
            Section("Global Hotkeys") {
                VStack(alignment: .leading, spacing: 12) {
                    HotkeyRow(
                        title: "Main Menu",
                        name: .showMainMenu,
                        description: "Open clipboard history menu"
                    )

                    HotkeyRow(
                        title: "Snippets Menu",
                        name: .showSnippetsMenu,
                        description: "Open snippets menu"
                    )

                    HotkeyRow(
                        title: "Snippet Editor",
                        name: .showSnippetEditor,
                        description: "Open snippet editor window"
                    )

                    HotkeyRow(
                        title: "Clear History",
                        name: .clearHistory,
                        description: "Clear clipboard history"
                    )
                }
            }

            Section("Paste Modifiers") {
                Text("Hold ⌥ Option while pasting to paste as plain text")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Hold ⌘ Command while pasting to paste without adding to history")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Tips") {
                Text("• Press Escape to close any menu")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("• Use number keys 1-9, 0 to quickly select items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct HotkeyRow: View {
    let title: String
    let name: KeyboardShortcuts.Name
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.body)

                Spacer()

                KeyboardShortcuts.Recorder(for: name)
            }

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    HotkeySettingsView()
}
