import Foundation

extension String {
    /// Check if string contains Hebrew characters
    var isHebrew: Bool {
        guard let first = self.first else { return false }
        let scalar = first.unicodeScalars.first!
        return (0x0590...0x05FF).contains(scalar.value) // Hebrew Unicode block
    }

    /// Check if string should be displayed RTL
    var isRTL: Bool {
        let rtlLanguages = ["he", "ar", "fa", "ur"]
        let language = NSLinguisticTagger.dominantLanguage(for: self)
        return rtlLanguages.contains(language ?? "")
    }
}
