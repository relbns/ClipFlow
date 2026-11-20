import Carbon.HIToolbox

/// The keyboard layouts enabled in System Settings, read through Text Input Sources.
enum KeyboardLayouts {
    /// The current layout and the first enabled layout of another language, with what each types per key.
    static func currentPair() -> LayoutPair? {
        guard let current = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let currentID = string(current, kTISPropertyInputSourceID) else { return nil }
        let currentLanguage = languages(of: current).first
        guard let other = layouts().first(where: { source in
            string(source, kTISPropertyInputSourceID) != currentID && languages(of: source).first != currentLanguage
        }) else { return nil }
        return pair(current, other)
    }

    /// The pair for two layouts by id, installed ones included; for tests and diagnostics.
    static func pair(_ firstID: String, _ secondID: String) -> LayoutPair? {
        let installed = layouts(includeAllInstalled: true)
        guard let first = installed.first(where: { string($0, kTISPropertyInputSourceID) == firstID }),
              let second = installed.first(where: { string($0, kTISPropertyInputSourceID) == secondID }) else { return nil }
        return pair(first, second)
    }

    static func select(_ inputSourceID: String) {
        guard let source = layouts().first(where: { string($0, kTISPropertyInputSourceID) == inputSourceID }) else { return }
        TISSelectInputSource(source)
    }

    private static func pair(_ first: TISInputSource, _ second: TISInputSource) -> LayoutPair? {
        guard let firstID = string(first, kTISPropertyInputSourceID), let secondID = string(second, kTISPropertyInputSourceID),
              let firstKeys = keyCharacters(first), let secondKeys = keyCharacters(second) else { return nil }
        let secondByKey = Dictionary(secondKeys, uniquingKeysWith: { kept, _ in kept })
        let keys = firstKeys.compactMap { key, character in secondByKey[key].map { (character, $0) } }
        return LayoutPair(first: firstID, second: secondID, keys: keys)
    }

    private struct Key: Hashable {
        let code: UInt16
        let shift: Bool
    }

    private static func layouts(includeAllInstalled: Bool = false) -> [TISInputSource] {
        let filter = [
            kTISPropertyInputSourceType as String: kTISTypeKeyboardLayout as String,
            kTISPropertyInputSourceIsSelectCapable as String: true
        ] as CFDictionary
        return (TISCreateInputSourceList(filter, includeAllInstalled)?.takeRetainedValue() as? [TISInputSource]) ?? []
    }

    /// The printable character each key types, with and without Shift, in sorted key order.
    private static func keyCharacters(_ source: TISInputSource) -> [(Key, Character)]? {
        guard let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue() as Data
        return data.withUnsafeBytes { buffer -> [(Key, Character)]? in
            guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            var result: [(Key, Character)] = []
            for shift in [false, true] {
                for code in UInt16(0)..<128 {
                    var deadKeyState: UInt32 = 0
                    var length = 0
                    var characters = [UniChar](repeating: 0, count: 4)
                    let modifiers = UInt32(shift ? (shiftKey >> 8) & 0xFF : 0)
                    let status = UCKeyTranslate(
                        layout, code, UInt16(kUCKeyActionDown), modifiers, UInt32(LMGetKbdType()),
                        OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeyState, characters.count, &length, &characters
                    )
                    let text = String(utf16CodeUnits: characters, count: length)
                    guard status == noErr, text.count == 1, let character = text.first,
                          !character.isWhitespace, character.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) })
                    else { continue }
                    result.append((Key(code: code, shift: shift), character))
                }
            }
            return result
        }
    }

    private static func string(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let property = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(property).takeUnretainedValue() as String
    }

    private static func languages(of source: TISInputSource) -> [String] {
        guard let property = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) else { return [] }
        return (Unmanaged<CFArray>.fromOpaque(property).takeUnretainedValue() as? [String]) ?? []
    }
}
