import KeyboardShortcuts
import SwiftUI

struct HotkeySettingsView: View {
    var body: some View {
        SettingsPage {
            CFSettingsRow(label: L("hotkey_history"), hint: L("hotkey_history_hint")) {
                KeyboardShortcuts.Recorder(for: .showHistoryMenu)
            }
            CFSettingsRow(label: L("hotkey_editor"), hint: L("hotkey_no_default_hint")) {
                KeyboardShortcuts.Recorder(for: .showSnippetEditor)
            }
            CFSettingsRow(label: L("hotkey_clear"), hint: L("hotkey_no_default_hint"), isLast: true) {
                KeyboardShortcuts.Recorder(for: .clearHistory)
            }
        }
    }
}
