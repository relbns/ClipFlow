import SwiftUI

/// The interface language: "system" follows macOS, or a fixed "en" / "he".
@MainActor
final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    static let supported = ["en", "he"]
    static let choiceKey = "preferredLanguage"

    /// What the user picked: "system", "en" or "he".
    @Published private(set) var choice: String
    /// The language actually shown, always one of `supported`.
    @Published private(set) var currentLanguage: String
    @Published private(set) var layoutDirection: LayoutDirection = .leftToRight
    @Published private var cachedBundle: Bundle = .main

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.choiceKey) ?? "system"
        choice = Self.supported.contains(saved) ? saved : "system"
        currentLanguage = "en"
        apply()
    }

    func setLanguage(_ newChoice: String) {
        choice = Self.supported.contains(newChoice) ? newChoice : "system"
        UserDefaults.standard.set(choice, forKey: Self.choiceKey)
        apply()
    }

    var bundle: Bundle { cachedBundle }

    /// Shows `language` without saving anything, for rendering snapshots.
    func preview(_ language: String) {
        currentLanguage = Self.supported.contains(language) ? language : "en"
        layoutDirection = currentLanguage == "he" ? .rightToLeft : .leftToRight
        cachedBundle = Bundle.main.path(forResource: currentLanguage, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
    }

    private func apply() {
        if choice == "system" {
            // Our own override would otherwise hide the system's language from Locale and Bundle.
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            currentLanguage = Self.resolve(Self.systemLanguages())
        } else {
            UserDefaults.standard.set([choice], forKey: "AppleLanguages")
            currentLanguage = choice
        }
        layoutDirection = currentLanguage == "he" ? .rightToLeft : .leftToRight
        cachedBundle = Bundle.main.path(forResource: currentLanguage, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
    }

    /// The user's languages from System Settings, ignoring any per-app override.
    static func systemLanguages() -> [String] {
        let global = CFPreferencesCopyValue(
            "AppleLanguages" as CFString, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost
        ) as? [String]
        return global ?? Locale.preferredLanguages
    }

    /// The first preferred language ClipFlow has a translation for, else English.
    static func resolve(_ preferred: [String]) -> String {
        for language in preferred {
            let code = String(language.prefix(2)).lowercased()
            if code == "iw" { return "he" }
            if supported.contains(code) { return code }
        }
        return "en"
    }
}
