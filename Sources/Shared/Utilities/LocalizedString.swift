import Foundation

/// Helper for localized strings
@MainActor
func L(_ key: String) -> String {
    let localized = NSLocalizedString(key, bundle: LanguageManager.shared.bundle, comment: "")
    if localized != key { return localized }
    let english = Bundle.main.path(forResource: "en", ofType: "lproj").flatMap(Bundle.init(path:))
    return english.map { NSLocalizedString(key, bundle: $0, comment: "") } ?? key
}

/// Picks `<key>_one` for a count of 1 and `<key>_other` otherwise, formatted with the count.
@MainActor
func L(_ key: String, count: Int) -> String {
    L(count == 1 ? key + "_one" : key + "_other", count)
}

@MainActor
func L(_ key: String, _ args: CVarArg...) -> String {
    let format = L(key)
    return String(format: format, arguments: args)
}
