import Foundation

struct ExpansionCandidate: Equatable {
    let id: String
    let abbreviation: String
    let trigger: ExpandTrigger
    let caseSensitive: Bool
    /// nil means the snippet may expand in any app.
    let allowedApps: Set<String>?
    let deniedApps: Set<String>
}

struct AbbreviationMatch: Equatable {
    let candidateID: String
    /// Characters to delete before inserting: the abbreviation plus the trigger key, if one was typed.
    let deleteCount: Int
    /// The typed trigger to put back after the expansion (a space or punctuation), so typing flows on.
    let trailingText: String
}

enum AbbreviationMatcher {
    /// Candidates must be sorted longest abbreviation first, so `.sig2` wins over `.sig`.
    static func match(
        buffer: String,
        candidates: [ExpansionCandidate],
        frontmostApp: String
    ) -> AbbreviationMatch? {
        guard let last = buffer.last else { return nil }

        for candidate in candidates where !candidate.abbreviation.isEmpty {
            if candidate.deniedApps.contains(frontmostApp) { continue }
            if let allowed = candidate.allowedApps, !allowed.contains(frontmostApp) { continue }

            let body: Substring
            if candidate.trigger == .any {
                body = Substring(buffer)
            } else {
                guard isValidTrigger(last, for: candidate.trigger) else { continue }
                body = buffer.dropLast()
            }

            guard let abbreviationStart = suffixStart(of: candidate.abbreviation, in: body, caseSensitive: candidate.caseSensitive) else {
                continue
            }
            if abbreviationStart > body.startIndex {
                let preceding = body[body.index(before: abbreviationStart)]
                if preceding.isLetter || preceding.isNumber { continue }
            }

            let typedTrigger = candidate.trigger == .any ? 0 : 1
            return AbbreviationMatch(
                candidateID: candidate.id,
                deleteCount: candidate.abbreviation.count + typedTrigger,
                trailingText: typedTrigger == 1 && keepsTrigger(last) ? String(last) : ""
            )
        }
        return nil
    }

    static func isValidTrigger(_ char: Character, for trigger: ExpandTrigger) -> Bool {
        switch trigger {
        case .any:
            return true
        case .space:
            return char == " "
        case .delimiter:
            return (char.isWhitespace && !char.isNewline && char != "\t") || char.isPunctuation || char.isSymbol
        case .tab:
            return char == "\t"
        case .enter:
            return char == "\r" || char == "\n"
        }
    }

    private static func keepsTrigger(_ char: Character) -> Bool {
        char != "\t" && char != "\r" && char != "\n"
    }

    private static func suffixStart(of abbreviation: String, in body: Substring, caseSensitive: Bool) -> String.Index? {
        guard body.count >= abbreviation.count else { return nil }
        let start = body.index(body.endIndex, offsetBy: -abbreviation.count)
        let tail = body[start...]
        let matches = caseSensitive
            ? tail == Substring(abbreviation)
            : tail.compare(abbreviation, options: [.caseInsensitive]) == .orderedSame
        return matches ? start : nil
    }
}

struct TypingBuffer {
    private(set) var text = ""
    let maxLength: Int

    init(maxLength: Int = 64) {
        self.maxLength = maxLength
    }

    mutating func append(_ characters: String) {
        text.append(characters)
        if text.count > maxLength {
            text = String(text.suffix(maxLength))
        }
    }

    mutating func deleteBackward() {
        if !text.isEmpty { text.removeLast() }
    }

    mutating func reset() {
        text = ""
    }
}
