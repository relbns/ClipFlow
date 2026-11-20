import Foundation

/// What two keyboard layouts type on the same keys, in both directions.
struct LayoutPair: Equatable {
    let first: String
    let second: String
    let firstToSecond: [Character: Character]
    let secondToFirst: [Character: Character]

    /// `keys` lists what each layout types on one key; a character keeps its first key.
    init(first: String, second: String, keys: [(Character, Character)]) {
        self.first = first
        self.second = second
        var forward: [Character: Character] = [:]
        var backward: [Character: Character] = [:]
        for (a, b) in keys where a != b {
            if forward[a] == nil { forward[a] = b }
            if backward[b] == nil { backward[b] = a }
        }
        firstToSecond = forward
        secondToFirst = backward
    }

    static func == (lhs: LayoutPair, rhs: LayoutPair) -> Bool {
        lhs.first == rhs.first && lhs.second == rhs.second
    }
}

/// Retypes text as if its keys had been pressed in the other layout ("akuo" ↔ "שלום").
enum LayoutConverter {
    struct Result: Equatable {
        let text: String
        /// True when the text was typed in `first` and now reads as `second`.
        let toSecond: Bool
    }

    /// The direction follows the letters that belong to only one layout; nil when nothing would change.
    static func convert(_ text: String, with pair: LayoutPair) -> Result? {
        let firstLetters = text.filter { pair.belongsToFirst($0) }.count
        let secondLetters = text.filter { pair.belongsToSecond($0) }.count
        guard firstLetters + secondLetters > 0 else { return nil }
        let toSecond = firstLetters >= secondLetters
        let map = toSecond ? pair.firstToSecond : pair.secondToFirst
        let converted = String(text.map { map[$0] ?? $0 })
        return converted == text ? nil : Result(text: converted, toSecond: toSecond)
    }

    /// The end of typed text written in one layout: "שלום עולם akuo" gives " akuo", so text typed right stays.
    static func trailingRun(of text: String, with pair: LayoutPair) -> String {
        var runIsFirst: Bool?
        var start = text.endIndex
        while start > text.startIndex {
            let previous = text.index(before: start)
            let character = text[previous]
            let isFirst = pair.belongsToFirst(character) ? true : pair.belongsToSecond(character) ? false : nil
            if let isFirst {
                if let runIsFirst, runIsFirst != isFirst { break }
                runIsFirst = isFirst
            }
            start = previous
        }
        return String(text[start...])
    }

    /// Of the pairs (current layout, another layout), the one whose second layout the text's letters come from,
    /// else the first pair, which the caller orders by the layout used most recently.
    static func choosePair(for text: String, among pairs: [LayoutPair]) -> LayoutPair? {
        var best: (pair: LayoutPair, letters: Int)?
        for pair in pairs {
            let letters = text.filter { pair.belongsToSecond($0) }.count
            if letters > (best?.letters ?? 0) { best = (pair, letters) }
        }
        return best?.pair ?? pairs.first
    }
}

extension LayoutPair {
    func belongsToFirst(_ character: Character) -> Bool {
        character.isLetter && firstToSecond[character] != nil && secondToFirst[character] == nil
    }

    func belongsToSecond(_ character: Character) -> Bool {
        character.isLetter && secondToFirst[character] != nil && firstToSecond[character] == nil
    }
}
