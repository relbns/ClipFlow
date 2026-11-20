import Carbon.HIToolbox
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
        tap(keyCode(for: "v") ?? Key.v, flags: .maskCommand)
    }

    /// The key that types `character` in the current Latin layout, so Cmd+V stays Cmd+V on Dvorak or AZERTY.
    static func keyCode(for character: Character) -> CGKeyCode? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let layoutData = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue() as Data
        let target = String(character)

        return layoutData.withUnsafeBytes { buffer -> CGKeyCode? in
            guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            for code in 0..<CGKeyCode(128) {
                var deadKeyState: UInt32 = 0
                var length = 0
                var characters = [UniChar](repeating: 0, count: 4)
                let status = UCKeyTranslate(
                    layout, code, UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                    OptionBits(1 << kUCKeyTranslateNoDeadKeysBit), &deadKeyState, characters.count, &length, &characters
                )
                if status == noErr, String(utf16CodeUnits: characters, count: length) == target {
                    return code
                }
            }
            return nil
        }
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
