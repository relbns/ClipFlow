import KeyboardShortcuts

/// Only Control+Command shortcuts, which apps rarely use, get a global default. A default on a common
/// shortcut (such as Cmd+E or Shift+Cmd+V) would take that shortcut away from every other app.
extension KeyboardShortcuts.Name {
    static let showHistoryMenu = Self("showHistoryMenu", default: .init(.v, modifiers: [.command, .control]))
    static let fixKeyboardLayout = Self("fixKeyboardLayout", default: .init(.l, modifiers: [.command, .control]))
    static let pastePlainText = Self("pastePlainText", default: .init(.v, modifiers: [.command, .control, .shift]))
    static let showSnippetEditor = Self("showSnippetEditor")
    static let clearHistory = Self("clearHistory")
}

@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()

    private init() {}

    func setupHotkeys(
        onHistoryMenu: @escaping () -> Void,
        onSnippetEditor: @escaping () -> Void,
        onClearHistory: @escaping () -> Void,
        onFixLayout: @escaping () -> Void,
        onPastePlainText: @escaping () -> Void
    ) {
        KeyboardShortcuts.onKeyUp(for: .pastePlainText, action: onPastePlainText)
        KeyboardShortcuts.onKeyUp(for: .showHistoryMenu, action: onHistoryMenu)
        KeyboardShortcuts.onKeyUp(for: .fixKeyboardLayout, action: onFixLayout)
        KeyboardShortcuts.onKeyUp(for: .showSnippetEditor, action: onSnippetEditor)
        KeyboardShortcuts.onKeyUp(for: .clearHistory, action: onClearHistory)
    }
}
