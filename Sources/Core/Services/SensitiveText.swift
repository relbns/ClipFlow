import Foundation

enum SensitiveKind: String, CaseIterable {
    case oneTimeCode, cardNumber, iban

    var defaultsKey: String { "sensitiveDetect." + rawValue }
}

/// What happens to a copied one-time code, card number or IBAN.
enum SensitiveHandling: String, CaseIterable {
    case keep, expire, skip
}

/// Recognizes a clip that is, as a whole, a one-time code, a card number or an IBAN. Text that only contains one
/// (an email quoting a card number) is not matched.
enum SensitiveText {
    static let handlingKey = "sensitiveClips"
    static let minutesKey = "sensitiveClipsMinutes"
    static let clearClipboardKey = "sensitiveClipsClearClipboard"
    static let minuteChoices = [1, 5, 15, 60]

    static func kind(of text: String) -> SensitiveKind? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= 64 else { return nil }
        if isOneTimeCode(trimmed) { return .oneTimeCode }
        if isCardNumber(trimmed) { return .cardNumber }
        if isIBAN(trimmed) { return .iban }
        return nil
    }

    /// 6 to 8 digits, also split in two by a space or a dash, optionally after a letter prefix like `G-`.
    /// Four digits are left out: years and short numbers are copied far more often than four-digit codes.
    static func isOneTimeCode(_ text: String) -> Bool {
        text.range(of: "^(?:[A-Z]-)?(?:[0-9]{6,8}|[0-9]{3,4}[ -][0-9]{3,4})$", options: .regularExpression) != nil
    }

    /// 13 to 19 digits, single spaces or dashes allowed between them, starting with 2-6 and passing the Luhn check.
    static func isCardNumber(_ text: String) -> Bool {
        guard text.range(of: "^[0-9](?:[ -]?[0-9]){12,18}$", options: .regularExpression) != nil else { return false }
        let digits = text.compactMap(\.wholeNumberValue)
        guard let first = digits.first, (2...6).contains(first) else { return false }
        let sum = digits.reversed().enumerated().reduce(0) { total, entry in
            guard entry.offset % 2 == 1 else { return total + entry.element }
            let doubled = entry.element * 2
            return total + (doubled > 9 ? doubled - 9 : doubled)
        }
        return sum % 10 == 0
    }

    /// A country code, two check digits and 11 to 30 letters or digits, spaces allowed, passing the mod-97 check.
    static func isIBAN(_ text: String) -> Bool {
        let compact = text.replacingOccurrences(of: " ", with: "").uppercased()
        guard compact.range(of: "^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$", options: .regularExpression) != nil else { return false }
        var remainder = 0
        for character in compact.dropFirst(4) + compact.prefix(4) {
            guard let ascii = character.asciiValue else { return false }
            let value = character.isNumber ? Int(ascii) - 48 : Int(ascii) - 55
            remainder = (remainder * (value > 9 ? 100 : 10) + value) % 97
        }
        return remainder == 1
    }

    /// The kind of this clip when the user asked to detect it.
    static func detectedKind(of capture: ClipCapture, defaults: UserDefaults) -> SensitiveKind? {
        guard capture.kind == .text || capture.kind == .rtf, let kind = kind(of: capture.text),
              defaults.bool(forKey: kind.defaultsKey) else { return nil }
        return kind
    }

    static func handling(in defaults: UserDefaults) -> SensitiveHandling {
        SensitiveHandling(rawValue: defaults.string(forKey: handlingKey) ?? "") ?? .expire
    }

    static func lifetime(in defaults: UserDefaults) -> TimeInterval {
        TimeInterval(max(1, defaults.integer(forKey: minutesKey))) * 60
    }
}
