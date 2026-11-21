import KeyboardShortcuts
import SwiftUI

struct HotkeySettingsView: View {
    @AppStorage("layoutFixSwitchesKeyboard") private var layoutFixSwitchesKeyboard = true
    @AppStorage(PasteStack.orderKey) private var stackOrder = PasteStack.Order.copied.rawValue
    @AppStorage(PasteStack.endsWhenEmptyKey) private var stackEndsWhenEmpty = true

    private let orders = PasteStack.Order.allCases

    var body: some View {
        SettingsPage {
            CFSettingsRow(label: L("hotkey_history"), hint: L("hotkey_history_hint")) {
                KeyboardShortcuts.Recorder(for: .showHistoryMenu)
            }
            CFSettingsRow(label: L("hotkey_paste_plain"), hint: L("hotkey_paste_plain_hint")) {
                KeyboardShortcuts.Recorder(for: .pastePlainText)
            }
            CFSettingsRow(label: L("hotkey_paste_stack"), hint: L("hotkey_paste_stack_hint")) {
                KeyboardShortcuts.Recorder(for: .togglePasteStack)
            }
            CFSettingsRow(label: L("hotkey_paste_next"), hint: L("hotkey_paste_next_hint")) {
                KeyboardShortcuts.Recorder(for: .pasteNextFromStack)
            }
            CFSettingsRow(label: L("pref_stack_order"), hint: L("pref_stack_order_hint")) {
                CFSegmentedControl(
                    selection: Binding(
                        get: { orders.firstIndex { $0.rawValue == stackOrder } ?? 0 },
                        set: { stackOrder = orders[$0].rawValue }
                    ),
                    options: orders.map { L("stack_order_\($0.rawValue)") }
                )
            }
            CFSettingsRow(label: L("pref_stack_ends"), hint: L("pref_stack_ends_hint")) {
                CFToggle(isOn: $stackEndsWhenEmpty).accessibilityLabel(L("pref_stack_ends"))
            }
            CFSettingsRow(label: L("hotkey_capture_text"), hint: L("hotkey_capture_text_hint")) {
                KeyboardShortcuts.Recorder(for: .captureScreenText)
            }
            CFSettingsRow(label: L("hotkey_capture_image"), hint: L("hotkey_capture_image_hint")) {
                KeyboardShortcuts.Recorder(for: .captureScreenImage)
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
