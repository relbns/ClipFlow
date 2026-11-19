import Foundation

/// Helper for localized strings
@MainActor
func L(_ key: String) -> String {
    let localized = NSLocalizedString(key, bundle: LanguageManager.shared.bundle, comment: "")
    if localized != key { return localized }
    let english = Bundle.main.path(forResource: "en", ofType: "lproj").flatMap(Bundle.init(path:))
    return english.map { NSLocalizedString(key, bundle: $0, comment: "") } ?? key
}

@MainActor
func L(_ key: String, _ args: CVarArg...) -> String {
    let format = L(key)
    return String(format: format, arguments: args)
}
