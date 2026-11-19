import CoreGraphics

/// Posts keystrokes tagged with a marker, so ClipFlow's own event tap can ignore them.
enum SyntheticKeyboard {
    static let marker: Int64 = 0x434C_4950

    private enum Key {
        static let delete: CGKeyCode = 0x33
        static let v: CGKeyCode = 0x09
        static let leftArrow: CGKeyCode = 0x7B
    }

    static func isSynthetic(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == marker
    }

    static func deleteBackward(count: Int) {
        for _ in 0..<max(0, count) { tap(Key.delete) }
    }

    static func paste() {
        tap(Key.v, flags: .maskCommand)
    }

    static func moveLeft(count: Int) {
        for _ in 0..<max(0, count) { tap(Key.leftArrow) }
    }

    private static func tap(_ key: CGKeyCode, flags: CGEventFlags = []) {
        let source = CGEventSource(stateID: .privateState)
        source?.userData = marker
        for isDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: isDown) else { continue }
            event.flags = flags
            event.setIntegerValueField(.eventSourceUserData, value: marker)
            event.post(tap: .cghidEventTap)
        }
    }
}
