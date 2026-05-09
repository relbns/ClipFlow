import KeyboardShortcuts
import Combine

extension KeyboardShortcuts.Name {
    static let showMainMenu = Self("showMainMenu", default: .init(.v, modifiers: [.command, .shift]))
    static let showHistoryMenu = Self("showHistoryMenu", default: .init(.v, modifiers: [.command, .control]))
    static let showSnippetsMenu = Self("showSnippetsMenu", default: .init(.b, modifiers: [.command, .shift]))
    static let showSnippetEditor = Self("showSnippetEditor", default: .init(.e, modifiers: [.command]))
    static let clearHistory = Self("clearHistory", default: .init(.delete, modifiers: [.command, .option]))
}

@MainActor
class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()

    private init() {}

    func setupHotkeys(
        onMainMenu: @escaping () -> Void,
        onHistoryMenu: @escaping () -> Void,
        onSnippetsMenu: @escaping () -> Void,
        onSnippetEditor: @escaping () -> Void,
        onClearHistory: @escaping () -> Void
    ) {
        KeyboardShortcuts.onKeyUp(for: .showMainMenu) {
            onMainMenu()
        }

        KeyboardShortcuts.onKeyUp(for: .showHistoryMenu) {
            onHistoryMenu()
        }

        KeyboardShortcuts.onKeyUp(for: .showSnippetsMenu) {
            onSnippetsMenu()
        }

        KeyboardShortcuts.onKeyUp(for: .showSnippetEditor) {
            onSnippetEditor()
        }

        KeyboardShortcuts.onKeyUp(for: .clearHistory) {
            onClearHistory()
        }
    }
}
