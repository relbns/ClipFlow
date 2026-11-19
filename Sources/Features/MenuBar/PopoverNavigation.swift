import AppKit
import SwiftUI

/// Keyboard control of the history popover: arrows move, Return pastes, 1-9 and 0 paste directly
/// while the search field is empty, Esc closes. Every other key goes to the search field.
@MainActor
final class PopoverNavigation: ObservableObject {
    static let shared = PopoverNavigation()
    static let shortcutCount = 10

    weak var clipboardMonitor: ClipboardMonitor?
    var onClose: () -> Void = {}

    @Published var searchText = "" {
        didSet { selectedIndex = 0 }
    }
    @Published private(set) var selectedIndex = 0

    private var eventMonitor: Any?

    private enum KeyCode {
        static let down: UInt16 = 125
        static let up: UInt16 = 126
        static let returnKey: UInt16 = 36
        static let enter: UInt16 = 76
        static let escape: UInt16 = 53
    }

    var filteredClips: [SimpleClipItem] {
        let clips = clipboardMonitor?.clipHistory ?? []
        guard !searchText.isEmpty else { return Array(clips.prefix(30)) }
        return clips.filter {
            $0.content.localizedCaseInsensitiveContains(searchText) || $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// The clips numbered 1-9 and 0 in the popover, in order.
    var navigableClips: [SimpleClipItem] {
        Array(filteredClips.prefix(Self.shortcutCount))
    }

    var selectedID: UUID? {
        let clips = navigableClips
        return clips.indices.contains(selectedIndex) ? clips[selectedIndex].id : nil
    }

    func popoverWillShow() {
        searchText = ""
        selectedIndex = 0
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let key = KeyInput(event)
            let handled = MainActor.assumeIsolated { PopoverNavigation.shared.handle(key) }
            return handled ? nil : event
        }
    }

    func popoverDidClose() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        eventMonitor = nil
    }

    struct KeyInput: Sendable {
        let keyCode: UInt16
        let hasModifiers: Bool
        let characters: String?

        init(keyCode: UInt16, hasModifiers: Bool = false, characters: String? = nil) {
            self.keyCode = keyCode
            self.hasModifiers = hasModifiers
            self.characters = characters
        }

        init(_ event: NSEvent) {
            let modifiers = event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
                .subtracting([.numericPad, .function, .capsLock])
            self.init(keyCode: event.keyCode, hasModifiers: !modifiers.isEmpty, characters: event.characters)
        }
    }

    func handle(_ key: KeyInput) -> Bool {
        guard !key.hasModifiers else { return false }

        switch key.keyCode {
        case KeyCode.down:
            move(by: 1)
            return true
        case KeyCode.up:
            move(by: -1)
            return true
        case KeyCode.returnKey, KeyCode.enter:
            activate(at: selectedIndex)
            return true
        case KeyCode.escape:
            onClose()
            return true
        default:
            break
        }

        guard searchText.isEmpty,
              let characters = key.characters, characters.count == 1,
              let digit = Int(characters) else { return false }
        activate(at: digit == 0 ? 9 : digit - 1)
        return true
    }

    private func move(by delta: Int) {
        let count = navigableClips.count
        guard count > 0 else { return }
        selectedIndex = min(max(0, selectedIndex + delta), count - 1)
    }

    private func activate(at index: Int) {
        let clips = navigableClips
        guard clips.indices.contains(index) else { return }
        PasteCoordinator.shared.paste(clips[index])
    }
}

private struct SelectedClipIDKey: EnvironmentKey {
    static let defaultValue: UUID? = nil
}

extension EnvironmentValues {
    var selectedClipID: UUID? {
        get { self[SelectedClipIDKey.self] }
        set { self[SelectedClipIDKey.self] = newValue }
    }
}
