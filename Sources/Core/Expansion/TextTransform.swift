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
        case .titleCase: result = Self.titleCase(text)
        case .sentenceCase: result = Self.sentenceCase(text)
        case .trim: result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .collapseSpaces: result = text.replacingOccurrences(of: "(?<=\\S)[ \\t]{2,}", with: " ", options: .regularExpression)
        case .joinLines:
            result = text.replacingOccurrences(of: "\\s*\\R\\s*", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        case .removeEmptyLines:
            result = text.replacingOccurrences(of: "(?m)^[ \\t]*\\R", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\R[ \\t]*\\z", with: "", options: .regularExpression)
        case .camelCase:
            let words = Self.words(text)
            let cased = words.allSatisfy { word in word.first.map { $0.uppercased() != $0.lowercased() || $0.isNumber } ?? false }
            result = words.isEmpty || !cased ? nil : ([words[0]] + words.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }).joined()
        case .snakeCase: result = Self.words(text).joined(separator: "_")
        case .kebabCase: result = Self.words(text).joined(separator: "-")
        case .urlEncode: result = text.addingPercentEncoding(withAllowedCharacters: Self.unreserved)
        case .urlDecode: result = text.removingPercentEncoding
        case .base64Encode: result = Data(text.utf8).base64EncodedString()
        case .base64Decode:
            var base64 = text.filter { !$0.isWhitespace }
                .replacingOccurrences(of: "-", with: "+")
                .replacingOccurrences(of: "_", with: "/")
            base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
            result = Data(base64Encoded: base64).flatMap { String(data: $0, encoding: .utf8) }
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

    /// Text with no lowercase letter at all is shouting, so it is lowered first; otherwise acronyms and iPhone stay.
    private static func caseBase(_ text: String) -> String {
        text.contains(where: \.isLowercase) ? text : text.lowercased()
    }

    /// Capitalizes words written all in lowercase; a word with a capital already (NASA, iPhone) stays as typed.
    private static func titleCase(_ text: String) -> String {
        caseBase(text)
            .split(separator: " ", omittingEmptySubsequences: false)
            .map { word in
                guard !word.contains(where: \.isUppercase), let first = word.firstIndex(where: \.isLetter) else { return String(word) }
                return word[..<first] + word[first].uppercased() + word[word.index(after: first)...]
            }
            .joined(separator: " ")
    }

    /// Capitalizes the first letter and the first after ". ", "! ", "? " or a line break; nothing else changes.
    private static func sentenceCase(_ text: String) -> String {
        var result = ""
        var capitalizeNext = true
        var previous: Character?
        for character in caseBase(text) {
            if character.isLetter {
                result += capitalizeNext ? character.uppercased() : String(character)
                capitalizeNext = false
            } else {
                result.append(character)
                if character.isNewline || (character.isWhitespace && previous.map { ".!?".contains($0) } == true) {
                    capitalizeNext = true
                }
            }
            previous = character
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

    /// Re-indents valid JSON without parsing values, so numbers, key order and duplicates stay exactly as copied.
    private static func prettyJSON(_ text: String) -> String? {
        guard let data = text.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil else { return nil }
        var output = ""
        var depth = 0
        var inString = false
        var escaped = false
        let characters = Array(text)
        func newline() { output += "\n" + String(repeating: "  ", count: depth) }
        for (index, character) in characters.enumerated() {
            if inString {
                output.append(character)
                if escaped { escaped = false } else if character == "\\" { escaped = true } else if character == "\"" { inString = false }
                continue
            }
            switch character {
            case "\"":
                inString = true
                output.append(character)
            case "{", "[":
                let next = characters[(index + 1)...].first { !$0.isWhitespace }
                output.append(character)
                if next == "}" || next == "]" { continue }
                depth += 1
                newline()
            case "}", "]":
                if let last = output.last, last != "{", last != "[" {
                    depth -= 1
                    newline()
                }
                output.append(character)
            case ",":
                output.append(character)
                newline()
            case ":":
                output += ": "
            default:
                if !character.isWhitespace { output.append(character) }
            }
        }
        return output
    }

    /// Drops Hebrew vowel points and cantillation marks, also from precomposed letters; maqaf, paseq, sof pasuq and
    /// nun hafukha stay.
    private static func removeNiqqud(_ text: String) -> String {
        let kept: Set<UInt32> = [0x05BE, 0x05C0, 0x05C3, 0x05C6]
        var scalars = String.UnicodeScalarView()
        for scalar in text.decomposedStringWithCanonicalMapping.unicodeScalars where !((0x0591...0x05C7).contains(scalar.value) && !kept.contains(scalar.value)) {
            scalars.append(scalar)
        }
        return String(scalars).precomposedStringWithCanonicalMapping
    }
}
