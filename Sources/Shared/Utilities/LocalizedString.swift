import Foundation

/// Helper for localized strings
func L(_ key: String) -> String {
    // Try Bundle.main first (Xcode), then Bundle.module (SPM)
    let bundles = [Bundle.main, Bundle.module]

    for bundle in bundles {
        let localized = NSLocalizedString(key, bundle: bundle, comment: "")
        // If we got a translation (not the key itself), return it
        if localized != key {
            return localized
        }
    }

    // Fallback: return the key itself
    return key
}

func L(_ key: String, _ args: CVarArg...) -> String {
    let format = L(key)
    return String(format: format, arguments: args)
}
