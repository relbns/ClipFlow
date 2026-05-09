import Foundation
import AppKit

/// Processes dynamic variables in snippet content
actor VariableProcessor {

    func process(_ content: String) async -> String {
        var result = content

        // First, collect all custom variables that need prompts
        let customVariables = await collectCustomVariables(from: content)

        // Show fill-in dialog if there are custom variables
        var customValues: [String: String] = [:]
        if !customVariables.isEmpty {
            customValues = await showFillInDialog(for: customVariables)
        }

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

            let replacement: String
            if let customValue = customValues[varName] {
                replacement = customValue
            } else {
                replacement = await resolveVariable(name: varName, format: format)
            }

            if let fullRange = Range(match.range, in: content) {
                result.replaceSubrange(fullRange, with: replacement)
            }
        }

        return result
    }

    private func collectCustomVariables(from content: String) async -> [String: String] {
        var variables: [String: String] = [:]

        // Match {varname:prompt="text"}
        let promptPattern = #"\{([^}:]+):prompt="([^"]+)"\}"#
        guard let regex = try? NSRegularExpression(pattern: promptPattern) else {
            return variables
        }

        let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))

        for match in matches {
            guard let nameRange = Range(match.range(at: 1), in: content),
                  let promptRange = Range(match.range(at: 2), in: content) else { continue }

            let varName = String(content[nameRange])
            let promptText = String(content[promptRange])
            variables[varName] = promptText
        }

        return variables
    }

    @MainActor
    private func showFillInDialog(for variables: [String: String]) async -> [String: String] {
        var values: [String: String] = [:]

        let alert = NSAlert()
        alert.messageText = "Fill in snippet variables"
        alert.informativeText = "Enter values for the following fields:"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        // Create text fields for each variable
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 8
        stackView.alignment = .leading

        var textFields: [(String, NSTextField)] = []

        for (varName, promptText) in variables.sorted(by: { $0.key < $1.key }) {
            let label = NSTextField(labelWithString: promptText)
            let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            textField.placeholderString = varName

            stackView.addArrangedSubview(label)
            stackView.addArrangedSubview(textField)

            textFields.append((varName, textField))
        }

        alert.accessoryView = stackView

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            for (varName, textField) in textFields {
                values[varName] = textField.stringValue
            }
        }

        return values
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
