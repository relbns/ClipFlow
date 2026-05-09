import Foundation

/// Helper for localized strings
func L(_ key: String) -> String {
    return NSLocalizedString(key, comment: "")
}

func L(_ key: String, _ args: CVarArg...) -> String {
    return String(format: NSLocalizedString(key, comment: ""), arguments: args)
}
