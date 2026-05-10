import SwiftUI

/// Manages app language and layout direction
@MainActor
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set([currentLanguage], forKey: "AppleLanguages")
            updateLayoutDirection()
        }
    }

    @Published var layoutDirection: LayoutDirection = .leftToRight

    private init() {
        // Load saved language preference
        if let languages = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String],
           let savedLanguage = languages.first {
            currentLanguage = savedLanguage
        } else {
            currentLanguage = Locale.preferredLanguages.first ?? "en"
        }

        updateLayoutDirection()
    }

    func setLanguage(_ code: String) {
        if code == "system" {
            currentLanguage = Locale.preferredLanguages.first ?? "en"
        } else {
            currentLanguage = code
        }
    }

    private func updateLayoutDirection() {
        // Hebrew and Arabic are RTL
        let rtlLanguages = ["he", "ar", "fa", "ur"]
        let languageCode = String(currentLanguage.prefix(2))

        layoutDirection = rtlLanguages.contains(languageCode) ? .rightToLeft : .leftToRight
    }

    var bundle: Bundle {
        if currentLanguage == "system" {
            return Bundle.main
        }

        // Try to find localized bundle
        let languageCode = String(currentLanguage.prefix(2))

        // Check Bundle.module first (SPM)
        if let path = Bundle.module.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }

        // Check Bundle.main (Xcode)
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }

        // Fallback to main bundle
        return Bundle.main
    }
}
