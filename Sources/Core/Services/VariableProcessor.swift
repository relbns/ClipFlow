import Foundation
import AppKit

/// Processes dynamic variables in snippet content
actor VariableProcessor {

    func process(_ content: String) async -> String {
        var result = content

        // Find all variables: {varname} or {varname:format}
        let pattern = #"\{([^}:]+)(?::([^}]+))?\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return content
        }

        let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))

        // Process in reverse order to maintain indices
        for match in matches.reversed() {
            guard let varRange = Range(match.range(at: 1), in: content) else { continue }
            let varName = String(content[varRange])

            let format = match.range(at: 2).location != NSNotFound
                ? String(content[Range(match.range(at: 2), in: content)!])
                : nil

            let replacement = await resolveVariable(name: varName, format: format)

            if let fullRange = Range(match.range, in: content) {
                result.replaceSubrange(fullRange, with: replacement)
            }
        }

        return result
    }

    private func resolveVariable(name: String, format: String?) async -> String {
        switch name.lowercased() {
        case "date":
            return formatDate(format: format)

        case "time":
            return formatTime(format: format)

        case "clipboard":
            return await getClipboard()

        case "cursor":
            // Placeholder - cursor positioning handled separately
            return ""

        case "year":
            return String(Calendar.current.component(.year, from: Date()))

        case "month":
            return String(format: "%02d", Calendar.current.component(.month, from: Date()))

        case "day":
            return String(format: "%02d", Calendar.current.component(.day, from: Date()))

        default:
            // Unknown variable - return as-is
            return "{\(name)}"
        }
    }

    private func formatDate(format: String?) -> String {
        let formatter = DateFormatter()

        if let fmt = format {
            if fmt == "hebrew" {
                return Date().hebrewDateString()
            } else {
                formatter.dateFormat = fmt
            }
        } else {
            formatter.dateStyle = .medium
            formatter.locale = Locale.current
        }

        return formatter.string(from: Date())
    }

    private func formatTime(format: String?) -> String {
        let formatter = DateFormatter()

        if let fmt = format {
            formatter.dateFormat = fmt
        } else {
            formatter.timeStyle = .short
        }

        formatter.locale = Locale.current
        return formatter.string(from: Date())
    }

    @MainActor
    private func getClipboard() async -> String {
        return NSPasteboard.general.string(forType: .string) ?? ""
    }
}
