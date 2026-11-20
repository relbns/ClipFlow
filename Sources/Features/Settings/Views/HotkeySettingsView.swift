import KeyboardShortcuts
import SwiftUI

struct HotkeySettingsView: View {
    @AppStorage("layoutFixSwitchesKeyboard") private var layoutFixSwitchesKeyboard = true

    var body: some View {
        SettingsPage {
            CFSettingsRow(label: L("hotkey_history"), hint: L("hotkey_history_hint")) {
                KeyboardShortcuts.Recorder(for: .showHistoryMenu)
            }
            CFSettingsRow(label: L("hotkey_fix_layout"), hint: L("hotkey_fix_layout_hint")) {
                KeyboardShortcuts.Recorder(for: .fixKeyboardLayout)
            }
            CFSettingsRow(label: L("pref_fix_layout_switch"), hint: L("pref_fix_layout_switch_hint")) {
                CFToggle(isOn: $layoutFixSwitchesKeyboard).accessibilityLabel(L("pref_fix_layout_switch"))
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
