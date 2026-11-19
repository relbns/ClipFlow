import KeyboardShortcuts

/// Only the history popover has a global default. A global default on a common shortcut
/// (such as Cmd+E or Shift+Cmd+V) would take that shortcut away from every other app.
extension KeyboardShortcuts.Name {
    static let showHistoryMenu = Self("showHistoryMenu", default: .init(.v, modifiers: [.command, .control]))
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
        onClearHistory: @escaping () -> Void
    ) {
        KeyboardShortcuts.onKeyUp(for: .showHistoryMenu, action: onHistoryMenu)
        KeyboardShortcuts.onKeyUp(for: .showSnippetEditor, action: onSnippetEditor)
        KeyboardShortcuts.onKeyUp(for: .clearHistory, action: onClearHistory)
    }
}
