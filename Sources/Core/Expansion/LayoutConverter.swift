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
        let firstLetters = text.filter { $0.isLetter && pair.firstToSecond[$0] != nil && pair.secondToFirst[$0] == nil }.count
        let secondLetters = text.filter { $0.isLetter && pair.secondToFirst[$0] != nil && pair.firstToSecond[$0] == nil }.count
        guard firstLetters + secondLetters > 0 else { return nil }
        let toSecond = firstLetters >= secondLetters
        let map = toSecond ? pair.firstToSecond : pair.secondToFirst
        let converted = String(text.map { map[$0] ?? $0 })
        return converted == text ? nil : Result(text: converted, toSecond: toSecond)
    }
}
