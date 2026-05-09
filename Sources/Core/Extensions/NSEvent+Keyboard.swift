import AppKit
import Carbon

extension NSEvent {
    var isHebrewKeyboard: Bool {
        guard let inputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return false
        }

        guard let sourceID = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) else {
            return false
        }

        let sourceIDString = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String
        return sourceIDString.contains("Hebrew") || sourceIDString.contains("he")
    }

    var keyboardLayoutName: String? {
        guard let inputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return nil
        }

        guard let sourceID = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) else {
            return nil
        }

        return Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String
    }

    var isRightToLeftKeyboard: Bool {
        guard let layout = keyboardLayoutName?.lowercased() else {
            return false
        }

        let rtlLanguages = ["hebrew", "arabic", "farsi", "persian", "urdu", "he", "ar", "fa", "ur"]
        return rtlLanguages.contains { layout.contains($0) }
    }

    static func currentKeyboardIsHebrew() -> Bool {
        guard let inputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return false
        }

        guard let sourceID = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) else {
            return false
        }

        let sourceIDString = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String
        return sourceIDString.contains("Hebrew") || sourceIDString.contains("he")
    }
}
