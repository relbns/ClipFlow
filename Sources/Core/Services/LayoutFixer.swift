import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// The fix-layout hotkey: retypes the selection, or what was just typed, in the other keyboard layout.
@MainActor
final class LayoutFixer {
    static let shared = LayoutFixer()

    /// Supplied by the expansion engine; nil unless the hotkey came right after typing.
    var takeTypedText: () -> String? = { nil }
    var defaults: UserDefaults = .standard
    private var isFixing = false
    /// Layouts the user switched to, newest first, so the fix aims at the one used before the current.
    private var recentLayoutIDs: [String] = []

    private enum Selection {
        case text(String)
        case empty
        case unknown
    }

    private init() {
        if let current = KeyboardLayouts.currentLayoutID() { recentLayoutIDs = [current] }
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String), object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.noteLayoutChange() }
        }
    }

    private func noteLayoutChange() {
        guard let current = KeyboardLayouts.currentLayoutID() else { return }
        recentLayoutIDs.removeAll { $0 == current }
        recentLayoutIDs.insert(current, at: 0)
        recentLayoutIDs = Array(recentLayoutIDs.prefix(8))
    }

    func fix() async {
        let typed = takeTypedText()
        guard !isFixing else { return }
        isFixing = true
        defer { isFixing = false }
        guard await SyntheticKeyboard.modifiersReleased() else { return }

        let pairs = layoutPairs
        guard !pairs.isEmpty else {
            Log.expansion.notice("Layout fix: no enabled keyboard layout of another language")
            NSSound.beep()
            return
        }

        let selection = Self.selectionInFocusedElement()
        let text: String
        let replacesTyped: Bool
        switch selection {
        case .text(let selected):
            text = selected
            replacesTyped = false
        case .empty, .unknown:
            guard let typed else {
                NSSound.beep()
                return
            }
            text = typed
            replacesTyped = true
        }

        guard let pair = LayoutConverter.choosePair(for: text, among: pairs) else { return }
        let source = replacesTyped ? LayoutConverter.trailingRun(of: text, with: pair) : text
        guard let result = LayoutConverter.convert(source, with: pair) else {
            NSSound.beep()
            return
        }
        let deleteCount = replacesTyped ? source.unicodeScalars.count : 0
        PasteEngine.shared.insert(RenderedSnippet(text: result.text, cursorOffsetFromEnd: 0), replacingTyped: deleteCount)
        if defaults.bool(forKey: "layoutFixSwitchesKeyboard") {
            KeyboardLayouts.select(result.toSecond ? pair.second : pair.first)
        }
        Log.expansion.info("Layout fix converted \(source.count, privacy: .public) characters (\(replacesTyped ? "typed" : "selected", privacy: .public))")
    }

    private static func selectionInFocusedElement() -> Selection {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.3)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return .unknown }
        let element = focused as! AXUIElement
        AXUIElementSetMessagingTimeout(element, 0.3)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value) == .success,
              let text = value as? String else { return .unknown }
        return text.isEmpty ? .empty : .text(text)
    }

    /// The current layout paired with each other-language layout, the most recently used first.
    var layoutPairs: [LayoutPair] {
        KeyboardLayouts.candidatePairs(recentIDs: Array(recentLayoutIDs.dropFirst()))
    }
}
