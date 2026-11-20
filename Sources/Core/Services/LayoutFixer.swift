import AppKit
import ApplicationServices

/// The fix-layout hotkey: retypes the selection, or what was just typed, in the other keyboard layout.
@MainActor
final class LayoutFixer {
    static let shared = LayoutFixer()

    /// Supplied by the expansion engine; nil when nothing was typed right before the hotkey.
    var takeTypedText: () -> String? = { nil }
    var defaults: UserDefaults = .standard

    private enum Selection {
        case text(String)
        case empty
        case unknown
    }

    private struct Source {
        let text: String
        let typedCount: Int
    }

    func fix() async {
        let typed = takeTypedText()
        await waitForModifierRelease()
        guard let pair = KeyboardLayouts.currentPair() else {
            Log.expansion.notice("Layout fix: fewer than two keyboard layouts of different languages are enabled")
            NSSound.beep()
            return
        }
        guard let source = await source(typed: typed),
              let result = LayoutConverter.convert(source.text, with: pair) else {
            NSSound.beep()
            return
        }
        PasteEngine.shared.insert(RenderedSnippet(text: result.text, cursorOffsetFromEnd: 0), replacingTyped: source.typedCount)
        if defaults.bool(forKey: "layoutFixSwitchesKeyboard") {
            KeyboardLayouts.select(result.toSecond ? pair.second : pair.first)
        }
        Log.expansion.info("Layout fix converted \(source.text.count, privacy: .public) characters (\(source.typedCount > 0 ? "typed" : "selected", privacy: .public))")
    }

    private func source(typed: String?) async -> Source? {
        switch Self.selectionInFocusedElement() {
        case .text(let text):
            return Source(text: text, typedCount: 0)
        case .empty:
            return typed.map { Source(text: $0, typedCount: $0.count) }
        case .unknown:
            if let typed { return Source(text: typed, typedCount: typed.count) }
            return await PasteEngine.shared.copySelection().flatMap { $0.isEmpty ? nil : Source(text: $0, typedCount: 0) }
        }
    }

    private static func selectionInFocusedElement() -> Selection {
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return .unknown }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focused as! AXUIElement, kAXSelectedTextAttribute as CFString, &value) == .success,
              let text = value as? String else { return .unknown }
        return text.isEmpty ? .empty : .text(text)
    }

    /// The hotkey fires while its modifiers may still be held; synthetic keys sent then would carry them.
    private func waitForModifierRelease() async {
        let held: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]
        for _ in 0..<100 where !CGEventSource.flagsState(.hidSystemState).isDisjoint(with: held) {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}
