import Foundation

struct SnippetPrompt: Equatable {
    let key: String
    let label: String
}

struct TemplateContext {
    var now: Date
    var timeZone: TimeZone
    var locale: Locale
    var clipboard: String
    var promptValues: [String: String] = [:]
}

struct RenderedSnippet: Equatable {
    let text: String
    /// How many characters the caret must move left after insertion to land on `{cursor}`.
    let cursorOffsetFromEnd: Int
}

/// Variables: {date}, {date:FORMAT}, {date:hebrew}, {time}, {time:FORMAT}, {clipboard}, {cursor},
/// {year}, {month}, {day}, {prompt:Label}, and the legacy {name:prompt="Label"}.
enum SnippetTemplate {
    private static let tokenPattern = try! NSRegularExpression(pattern: #"\{([^{}:]+)(?::([^{}]*))?\}"#)
    private static let legacyPromptPattern = try! NSRegularExpression(pattern: #"^prompt="([^"]*)"$"#)
    private static let cursorMarker = "\u{E000}"

    static func prompts(in content: String) -> [SnippetPrompt] {
        var seen = Set<String>()
        var result: [SnippetPrompt] = []
        for token in tokens(in: content) {
            guard let prompt = prompt(for: token), seen.insert(prompt.key).inserted else { continue }
            result.append(prompt)
        }
        return result
    }

    static func render(_ content: String, context: TemplateContext) -> RenderedSnippet {
        var result = ""
        var cursor = content.startIndex
        for token in tokens(in: content) {
            result += content[cursor..<token.range.lowerBound]
            result += resolve(token, context: context)
            cursor = token.range.upperBound
        }
        result += content[cursor...]

        guard let markerRange = result.range(of: cursorMarker) else {
            return RenderedSnippet(text: result, cursorOffsetFromEnd: 0)
        }
        let offset = result[markerRange.upperBound...].replacingOccurrences(of: cursorMarker, with: "").count
        return RenderedSnippet(text: result.replacingOccurrences(of: cursorMarker, with: ""), cursorOffsetFromEnd: offset)
    }

    private struct Token {
        let range: Range<String.Index>
        let raw: String
        let name: String
        let argument: String?
    }

    private static func tokens(in content: String) -> [Token] {
        let nsRange = NSRange(content.startIndex..., in: content)
        return tokenPattern.matches(in: content, range: nsRange).compactMap { match in
            guard let range = Range(match.range, in: content),
                  let nameRange = Range(match.range(at: 1), in: content) else { return nil }
            let argument = Range(match.range(at: 2), in: content).map { String(content[$0]) }
            return Token(range: range, raw: String(content[range]), name: String(content[nameRange]), argument: argument)
        }
    }

    private static func prompt(for token: Token) -> SnippetPrompt? {
        guard let argument = token.argument else { return nil }
        if token.name.lowercased() == "prompt" {
            let label = argument.trimmingCharacters(in: .whitespaces)
            return label.isEmpty ? nil : SnippetPrompt(key: label, label: label)
        }
        let nsRange = NSRange(argument.startIndex..., in: argument)
        guard let match = legacyPromptPattern.firstMatch(in: argument, range: nsRange),
              let labelRange = Range(match.range(at: 1), in: argument) else { return nil }
        let label = String(argument[labelRange])
        return SnippetPrompt(key: token.name, label: label.isEmpty ? token.name : label)
    }

    private static func resolve(_ token: Token, context: TemplateContext) -> String {
        if let prompt = prompt(for: token) {
            return context.promptValues[prompt.key] ?? ""
        }
        switch token.name.lowercased() {
        case "date":
            if token.argument?.lowercased() == "hebrew" {
                return format(context, style: .long, calendar: Calendar(identifier: .hebrew), locale: Locale(identifier: "he_IL"))
            }
            return format(context, pattern: token.argument, dateStyle: .medium, timeStyle: .none)
        case "time":
            return format(context, pattern: token.argument, dateStyle: .none, timeStyle: .short)
        case "clipboard":
            return context.clipboard
        case "cursor":
            return cursorMarker
        case "year":
            return format(context, pattern: "yyyy", dateStyle: .none, timeStyle: .none)
        case "month":
            return format(context, pattern: "MM", dateStyle: .none, timeStyle: .none)
        case "day":
            return format(context, pattern: "dd", dateStyle: .none, timeStyle: .none)
        default:
            return token.raw
        }
    }

    private static func format(_ context: TemplateContext, pattern: String?, dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style) -> String {
        let formatter = DateFormatter()
        formatter.locale = context.locale
        formatter.timeZone = context.timeZone
        if let pattern, !pattern.isEmpty {
            formatter.dateFormat = pattern
        } else {
            formatter.dateStyle = dateStyle
            formatter.timeStyle = timeStyle
        }
        return formatter.string(from: context.now)
    }

    private static func format(_ context: TemplateContext, style: DateFormatter.Style, calendar: Calendar, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = context.timeZone
        formatter.dateStyle = style
        return formatter.string(from: context.now)
    }
}
