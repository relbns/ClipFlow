import Foundation

/// Rewrites a clip's text before it is pasted ("Paste as…").
enum TextTransform: String, CaseIterable, Identifiable {
    case uppercase, lowercase, titleCase, sentenceCase
    case trim, collapseSpaces, joinLines, removeEmptyLines
    case camelCase, snakeCase, kebabCase, urlEncode, urlDecode, base64Encode, base64Decode, prettyJSON
    case removeNiqqud, fixLayout

    enum Group: CaseIterable {
        case letterCase, whitespace, developer, hebrew
    }

    var id: String { rawValue }
    var titleKey: String { "transform_\(rawValue)" }

    var group: Group {
        switch self {
        case .uppercase, .lowercase, .titleCase, .sentenceCase: return .letterCase
        case .trim, .collapseSpaces, .joinLines, .removeEmptyLines: return .whitespace
        case .removeNiqqud, .fixLayout: return .hebrew
        default: return .developer
        }
    }

    /// The rewritten text; nil when the transform does not apply (invalid Base64 or JSON) or changes nothing.
    func apply(_ text: String, layoutPairs: [LayoutPair] = []) -> String? {
        let result: String?
        switch self {
        case .uppercase: result = text.uppercased()
        case .lowercase: result = text.lowercased()
        case .titleCase: result = text.capitalized
        case .sentenceCase: result = Self.sentenceCase(text)
        case .trim: result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .collapseSpaces: result = text.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        case .joinLines:
            result = text.replacingOccurrences(of: "\\s*\\R\\s*", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        case .removeEmptyLines:
            result = text.components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .joined(separator: "\n")
        case .camelCase:
            let words = Self.words(text)
            result = words.isEmpty ? nil : ([words[0]] + words.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }).joined()
        case .snakeCase: result = Self.words(text).joined(separator: "_")
        case .kebabCase: result = Self.words(text).joined(separator: "-")
        case .urlEncode: result = text.addingPercentEncoding(withAllowedCharacters: Self.unreserved)
        case .urlDecode: result = text.removingPercentEncoding
        case .base64Encode: result = Data(text.utf8).base64EncodedString()
        case .base64Decode:
            result = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines), options: .ignoreUnknownCharacters)
                .flatMap { String(data: $0, encoding: .utf8) }
        case .prettyJSON: result = Self.prettyJSON(text)
        case .removeNiqqud: result = Self.removeNiqqud(text)
        case .fixLayout:
            result = LayoutConverter.choosePair(for: text, among: layoutPairs)
                .flatMap { LayoutConverter.convert(text, with: $0)?.text }
        }
        guard let result, !result.isEmpty, result != text else { return nil }
        return result
    }

    private static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    private static func sentenceCase(_ text: String) -> String {
        var result = ""
        var capitalizeNext = true
        for character in text.lowercased() {
            if capitalizeNext, character.isLetter {
                result += character.uppercased()
                capitalizeNext = false
            } else {
                result.append(character)
            }
            if ".!?".contains(character) || character.isNewline { capitalizeNext = true }
        }
        return result
    }

    /// Lowercase words split at spaces, punctuation and camelCase humps ("userID list" → user, id, list).
    private static func words(_ text: String) -> [String] {
        let spaced = text
            .replacingOccurrences(of: "([a-z0-9])([A-Z])", with: "$1 $2", options: .regularExpression)
            .replacingOccurrences(of: "([A-Z]+)([A-Z][a-z])", with: "$1 $2", options: .regularExpression)
        return spaced.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .map { $0.lowercased() }
    }

    private static func prettyJSON(_ text: String) -> String? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes, .fragmentsAllowed])
        else { return nil }
        return String(data: pretty, encoding: .utf8)
    }

    /// Drops Hebrew vowel points and cantillation marks; maqaf, paseq, sof pasuq and nun hafukha stay.
    private static func removeNiqqud(_ text: String) -> String {
        let kept: Set<UInt32> = [0x05BE, 0x05C0, 0x05C3, 0x05C6]
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars where !((0x0591...0x05C7).contains(scalar.value) && !kept.contains(scalar.value)) {
            scalars.append(scalar)
        }
        return String(scalars)
    }
}
