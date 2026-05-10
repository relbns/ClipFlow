import Foundation

/// Helper for localized strings
@MainActor
func L(_ key: String) -> String {
    let languageManager = LanguageManager.shared
    let bundle = languageManager.bundle

    let localized = NSLocalizedString(key, bundle: bundle, comment: "")

    // If we got a translation (not the key itself), return it
    if localized != key {
        return localized
    }

    // Fallback: try other bundles
    let fallbackBundles = [Bundle.main, Bundle.module]
    for fallbackBundle in fallbackBundles {
        let fallbackLocalized = NSLocalizedString(key, bundle: fallbackBundle, comment: "")
        if fallbackLocalized != key {
            return fallbackLocalized
        }
    }

    // Last resort: return the key itself
    return key
}

@MainActor
func L(_ key: String, _ args: CVarArg...) -> String {
    let format = L(key)
    return String(format: format, arguments: args)
}
