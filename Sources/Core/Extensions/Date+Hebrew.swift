import Foundation

extension Date {
    /// Format date using Hebrew calendar
    func hebrewDateString(style: DateFormatter.Style = .long) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .hebrew)
        formatter.locale = Locale(identifier: "he_IL")
        formatter.dateStyle = style
        return formatter.string(from: self)
    }

    /// Format time in Hebrew locale
    func hebrewTimeString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "he_IL")
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}
