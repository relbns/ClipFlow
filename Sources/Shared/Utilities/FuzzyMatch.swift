import Foundation

/// Scores how well a search query matches a text; a higher score ranks first, nil is no match.
enum FuzzyMatch {
    static let exact = 1000
    static let prefix = 900
    static let wordStart = 800
    static let substring = 700
    private static let gapsCeiling = 600

    /// With `allowGaps`, the query's characters may also appear apart, in order ("esig" in "Email signature").
    static func score(_ query: String, in text: String, allowGaps: Bool = true) -> Int? {
        let needle = fold(query.trimmingCharacters(in: .whitespaces))
        let haystack = fold(text)
        guard !needle.isEmpty else { return nil }
        if haystack == needle { return exact }
        if let range = haystack.range(of: needle) {
            if range.lowerBound == haystack.startIndex { return prefix }
            return isBoundary(haystack[haystack.index(before: range.lowerBound)]) ? wordStart : substring
        }
        guard allowGaps, needle.count > 1 else { return nil }
        return gapsScore(Array(needle), in: Array(haystack))
    }

    /// Characters matched at a word start or right after the previous match score higher.
    private static func gapsScore(_ needle: [Character], in haystack: [Character]) -> Int? {
        var score = 0
        var index = 0
        var previousMatched = false
        for character in needle {
            var found = false
            while index < haystack.count {
                let candidate = haystack[index]
                let atWordStart = index == 0 || isBoundary(haystack[index - 1])
                index += 1
                if candidate == character {
                    score += (atWordStart ? 10 : 1) + (previousMatched ? 5 : 0)
                    previousMatched = true
                    found = true
                    break
                }
                previousMatched = false
            }
            if !found { return nil }
        }
        return min(score, gapsCeiling)
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    private static func isBoundary(_ character: Character) -> Bool {
        !(character.isLetter || character.isNumber)
    }
}
