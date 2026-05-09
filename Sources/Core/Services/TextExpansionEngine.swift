import Foundation
import CoreData
import AppKit

/// Handles text expansion matching and execution
actor TextExpansionEngine {
    private let context: NSManagedObjectContext
    private let pasteEngine: PasteEngine
    private let variableProcessor: VariableProcessor

    struct Match {
        let snippet: Snippet
        let abbreviationLength: Int
    }

    init(context: NSManagedObjectContext) {
        self.context = context
        self.pasteEngine = PasteEngine()
        self.variableProcessor = VariableProcessor()
    }

    /// Find matching snippet in the typed buffer
    func findMatch(in buffer: String, triggerChar: Character?) async -> Match? {
        // Get frontmost app bundle ID
        let frontmostApp = await getFrontmostAppBundleID()

        // Fetch all enabled snippets
        let request: NSFetchRequest<Snippet> = Snippet.fetchRequest()
        request.predicate = NSPredicate(format: "isEnabled == YES")

        guard let snippets = try? context.fetch(request) else {
            return nil
        }

        // Try to find a match
        for snippet in snippets {
            let abbrev = snippet.abbreviation

            // Check if buffer ends with abbreviation
            guard buffer.hasSuffix(abbrev) else { continue }

            // Check app-specific rules
            if snippet.restrictToApps {
                let allowedApps = snippet.appRules?.compactMap { $0.bundleIdentifier } ?? []
                if !allowedApps.isEmpty && !allowedApps.contains(frontmostApp) {
                    continue // Skip this snippet for current app
                }
            }

            // Check trigger character
            guard let trigger = triggerChar else { continue }

            let triggerType = snippet.expandTriggerType
            if isValidTrigger(trigger, for: triggerType) {
                return Match(snippet: snippet, abbreviationLength: abbrev.count)
            }
        }

        return nil
    }

    @MainActor
    private func getFrontmostAppBundleID() async -> String {
        if let app = NSWorkspace.shared.frontmostApplication {
            return app.bundleIdentifier ?? ""
        }
        return ""
    }

    /// Expand a matched snippet
    func expand(_ match: Match) async {
        let snippet = match.snippet

        // Delete the abbreviation (backspaces)
        await deleteCharacters(count: match.abbreviationLength)

        // Process variables in content
        let processedContent = await variableProcessor.process(snippet.content)

        // Paste the expanded text
        await pasteEngine.paste(processedContent)

        // Play sound if enabled
        if snippet.playSound {
            await playExpansionSound()
        }

        // Update statistics
        await updateStatistics(for: snippet)
    }

    private func isValidTrigger(_ char: Character, for trigger: ExpandTrigger) -> Bool {
        switch trigger {
        case .any:
            return true
        case .space:
            return char == " "
        case .delimiter:
            return char.isWhitespace || char.isPunctuation
        case .tab:
            return char == "\t"
        case .enter:
            return char == "\n" || char == "\r"
        }
    }

    private func deleteCharacters(count: Int) async {
        // Simulate backspace key presses
        for _ in 0..<count {
            let deleteDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x33, keyDown: true)
            let deleteUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x33, keyDown: false)

            deleteDown?.post(tap: .cghidEventTap)
            deleteUp?.post(tap: .cghidEventTap)

            try? await Task.sleep(nanoseconds: 1_000_000) // 1ms between keys
        }
    }

    @MainActor
    private func playExpansionSound() {
        NSSound.beep()
    }

    private func updateStatistics(for snippet: Snippet) async {
        await MainActor.run {
            snippet.useCount += 1
            snippet.lastUsed = Date()

            do {
                try context.save()
            } catch {
                print("❌ Failed to update snippet statistics: \(error)")
            }
        }
    }
}
