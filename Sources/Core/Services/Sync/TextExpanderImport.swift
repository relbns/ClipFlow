import Foundation

/// Reads TextExpander snippet groups: the web app's CSV export (abbreviation, snippet, label) and the Mac app's
/// `.textexpander` property list. Macros become ClipFlow variables where one exists; the rest stay as typed.
enum TextExpanderImport {
    struct Snippet: Equatable {
        let abbreviation: String
        let label: String
        let content: String
    }

    struct Group: Equatable {
        let name: String
        let snippets: [Snippet]
    }

    struct Result: Equatable {
        var groups: [Group] = []
        /// Abbreviations of AppleScript, shell and JavaScript snippets, which ClipFlow cannot run.
        var scriptSnippets: [String] = []
        /// Macros with no ClipFlow equivalent, kept as typed, such as `%snippet:` or `%key:`.
        var unsupportedMacros: Set<String> = []
    }

    enum ImportError: LocalizedError {
        case unreadable

        var errorDescription: String? { "The file is not a TextExpander CSV or snippet group." }
    }

    static func canRead(fileExtension: String) -> Bool {
        ["csv", "textexpander", "plist", "xml"].contains(fileExtension.lowercased())
    }

    static func parse(_ data: Data, fileName: String) throws -> Result {
        let fallbackName = (fileName as NSString).deletingPathExtension
        if let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
           !(plist is String) {
            return try parsePropertyList(plist, fallbackName: fallbackName)
        }
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw ImportError.unreadable
        }
        return try parseCSV(text, groupName: fallbackName)
    }

    // MARK: - CSV

    static func parseCSV(_ text: String, groupName: String) throws -> Result {
        var rows = csvRows(text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text)
        guard let first = rows.first else { throw ImportError.unreadable }
        let header = first.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        var columns = (abbreviation: 0, snippet: 1, label: rows.contains { $0.count > 2 } ? 2 : nil as Int?)
        if let abbreviation = header.firstIndex(of: "abbreviation"), let snippet = header.firstIndex(of: "snippet") {
            columns = (abbreviation, snippet, header.firstIndex(of: "label"))
            rows.removeFirst()
        } else if first.count < 2 || first.count > 3 {
            throw ImportError.unreadable
        }
        var result = Result()
        var snippets: [Snippet] = []
        for row in rows where row.count > max(columns.abbreviation, columns.snippet) {
            let abbreviation = row[columns.abbreviation].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !abbreviation.isEmpty else { continue }
            let label = columns.label.flatMap { $0 < row.count ? row[$0] : nil } ?? ""
            snippets.append(snippet(abbreviation: abbreviation, label: label, text: row[columns.snippet], result: &result))
        }
        result.groups = [Group(name: groupName, snippets: snippets)]
        return result
    }

    /// RFC 4180: commas and line breaks inside quotes, a doubled quote for a quote.
    static func csvRows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var characters = Array(text)[...]
        while let character = characters.popFirst() {
            if inQuotes {
                if character == "\"" {
                    if characters.first == "\"" {
                        field.append("\"")
                        characters.removeFirst()
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(character)
                }
                continue
            }
            switch character {
            case "\"": inQuotes = true
            case ",":
                row.append(field)
                field = ""
            case "\n", "\r\n", "\r":
                row.append(field)
                field = ""
                if row != [""] { rows.append(row) }
                row = []
            default: field.append(character)
            }
        }
        row.append(field)
        if row != [""] { rows.append(row) }
        return rows
    }

    // MARK: - Property list

    private static let snippetListKeys = ["snippetsTE2", "snippetPlists", "snippetsPlain", "snippets"]

    private static func parsePropertyList(_ plist: Any, fallbackName: String) throws -> Result {
        let groupDictionaries: [[String: Any]]
        if let dictionary = plist as? [String: Any] {
            groupDictionaries = [dictionary]
        } else if let array = plist as? [[String: Any]] {
            groupDictionaries = array
        } else {
            throw ImportError.unreadable
        }
        var result = Result()
        for dictionary in groupDictionaries {
            guard let entries = snippetListKeys.lazy.compactMap({ dictionary[$0] as? [[String: Any]] }).first else { continue }
            let info = dictionary["groupInfo"] as? [String: Any]
            let name = (info?["groupName"] as? String) ?? (dictionary["name"] as? String) ?? (dictionary["groupName"] as? String)
            var snippets: [Snippet] = []
            for entry in entries {
                let abbreviation = ((entry["abbreviation"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !abbreviation.isEmpty else { continue }
                if let type = entry["snippetType"] as? Int, type >= 2 {
                    result.scriptSnippets.append(abbreviation)
                    continue
                }
                let text = (entry["plainText"] as? String) ?? (entry["snippet"] as? String) ?? ""
                snippets.append(snippet(abbreviation: abbreviation, label: entry["label"] as? String ?? "", text: text, result: &result))
            }
            result.groups.append(Group(name: name?.isEmpty == false ? name! : fallbackName, snippets: snippets))
        }
        guard !result.groups.isEmpty else { throw ImportError.unreadable }
        return result
    }

    private static func snippet(abbreviation: String, label: String, text: String, result: inout Result) -> Snippet {
        let converted = convertMacros(text)
        result.unsupportedMacros.formUnion(converted.unsupported)
        let title = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return Snippet(abbreviation: abbreviation, label: title.isEmpty ? abbreviation : title, content: converted.content)
    }

    // MARK: - Macros

    private static let datePatterns: [String: String] = [
        "Y": "yyyy", "y": "yy", "m": "MM", "1m": "M", "B": "MMMM", "b": "MMM", "d": "dd", "1d": "d", "e": "d",
        "A": "EEEE", "a": "EEE", "H": "HH", "1H": "H", "I": "hh", "1I": "h", "M": "mm", "S": "ss", "p": "a",
        "Z": "zzz", "j": "DDD"
    ]
    private static let fillNames: Set<String> = ["fill", "filltext", "fillarea", "fillpopup"]

    /// TextExpander macros to ClipFlow variables. Literal text that looks like a ClipFlow variable is escaped first,
    /// so it still types as written.
    static func convertMacros(_ text: String) -> (content: String, unsupported: Set<String>) {
        let source = Array(SnippetTemplate.escaped(text))
        var output = ""
        var unsupported = Set<String>()
        var index = 0
        func rest(from start: Int) -> String { String(source[start...]) }
        while index < source.count {
            guard source[index] == "%", index + 1 < source.count else {
                output.append(source[index])
                index += 1
                continue
            }
            let tail = rest(from: index + 1)
            if tail.hasPrefix("%") {
                output += "%"
                index += 2
            } else if tail.hasPrefix("|") {
                output += "{cursor}"
                index += 2
            } else if tail.hasPrefix("clipboard") {
                output += "{clipboard}"
                index += 1 + "clipboard".count
            } else if let macro = namedMacro(tail) {
                if fillNames.contains(macro.name), let label = fillLabel(macro.argument) {
                    output += "{prompt:\(label)}"
                } else {
                    unsupported.insert("%" + macro.name)
                    output += "%" + macro.body
                }
                index += 1 + macro.body.count
            } else if tail.hasPrefix("@") {
                unsupported.insert("%@")
                output += "%"
                index += 1
            } else if let (token, pattern) = dateToken(tail) {
                output += "{date:\(pattern)}"
                index += 1 + token.count
            } else {
                output += "%"
                index += 1
            }
        }
        return (output, unsupported)
    }

    /// `name:argument%`, as in `%key:tab%` or `%filltext:name=First name:default=Ann%`. Names are words, so `%H:%M`
    /// stays two date macros.
    private static func namedMacro(_ text: String) -> (name: String, argument: String, body: String)? {
        guard let colon = text.firstIndex(of: ":"), let end = text[colon...].firstIndex(of: "%") else { return nil }
        let name = String(text[..<colon])
        guard name.count >= 3, name.allSatisfy({ $0.isLetter }), !text[colon..<end].contains("\n") else { return nil }
        return (name, String(text[text.index(after: colon)..<end]), String(text[...end]))
    }

    /// `name=First name:default=Ann` or the older `First name`.
    private static func fillLabel(_ argument: String) -> String? {
        let parts = argument.split(separator: ":", omittingEmptySubsequences: true).map(String.init)
        let named = parts.first { $0.hasPrefix("name=") }.map { String($0.dropFirst(5)) }
        let label = (named ?? parts.first { !$0.contains("=") } ?? "")
            .replacingOccurrences(of: "{", with: "(").replacingOccurrences(of: "}", with: ")")
            .trimmingCharacters(in: .whitespaces)
        return label.isEmpty ? nil : label
    }

    private static func dateToken(_ text: String) -> (String, String)? {
        if text.hasPrefix("1"), let next = text.dropFirst().first, let pattern = datePatterns["1\(next)"] {
            return ("1\(next)", pattern)
        }
        guard let first = text.first, let pattern = datePatterns[String(first)] else { return nil }
        return (String(first), pattern)
    }
}
