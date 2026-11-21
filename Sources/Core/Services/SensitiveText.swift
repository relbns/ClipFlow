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
    /// This Mac's first launch with the feature; history copied before it is never removed.
    static let sinceKey = "sensitiveClipsSince"
    static let minuteChoices = [1, 5, 15, 60]

    static func kind(of text: String) -> SensitiveKind? {
        let trimmed = text.replacingOccurrences(of: "\u{00A0}", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= 64 else { return nil }
        if isOneTimeCode(trimmed) { return .oneTimeCode }
        if isCardNumber(trimmed) { return .cardNumber }
        if isIBAN(trimmed) { return .iban }
        return nil
    }

    /// 6 digits, also as 3 and 3 split by a space or a dash, optionally after a letter prefix like `G-`. Other lengths
    /// are left out: postcodes, dates, years and phone numbers are copied far more often than such codes.
    static func isOneTimeCode(_ text: String) -> Bool {
        text.range(of: "^(?:[A-Z]-)?(?:[0-9]{6}|[0-9]{3}[ -][0-9]{3})$", options: .regularExpression) != nil
    }

    /// 13 to 19 digits, single spaces or dashes allowed between them, starting with 2-6 and passing the Luhn check.
    /// 15 digits only with the Amex prefix, since IMEIs are 15 Luhn-valid digits too.
    static func isCardNumber(_ text: String) -> Bool {
        guard text.range(of: "^[0-9](?:[ -]?[0-9]){12,18}$", options: .regularExpression) != nil else { return false }
        let digits = text.compactMap(\.wholeNumberValue)
        guard let first = digits.first, (2...6).contains(first) else { return false }
        if digits.count == 15, !(digits[0] == 3 && [4, 7].contains(digits[1])) { return false }
        let sum = digits.reversed().enumerated().reduce(0) { total, entry in
            guard entry.offset % 2 == 1 else { return total + entry.element }
            let doubled = entry.element * 2
            return total + (doubled > 9 ? doubled - 9 : doubled)
        }
        return sum % 10 == 0
    }

    /// A country code, two check digits and 11 to 30 letters or digits, spaces allowed, passing the mod-97 check.
    static func isIBAN(_ text: String) -> Bool {
        let compact = text.filter { !$0.isWhitespace }.uppercased()
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
        guard capture.kind == .text || capture.kind == .rtf else { return nil }
        return detectedKind(of: capture.text, defaults: defaults)
    }

    static func detectedKind(of text: String, defaults: UserDefaults) -> SensitiveKind? {
        guard let kind = kind(of: text), defaults.bool(forKey: kind.defaultsKey) else { return nil }
        return kind
    }

    static func handling(in defaults: UserDefaults) -> SensitiveHandling {
        SensitiveHandling(rawValue: defaults.string(forKey: handlingKey) ?? "") ?? .expire
    }

    static func lifetime(in defaults: UserDefaults) -> TimeInterval {
        TimeInterval(max(1, defaults.integer(forKey: minutesKey))) * 60
    }
}
