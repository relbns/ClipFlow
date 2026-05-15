import Foundation
import CoreData
import AppKit

/// Handles text expansion matching and execution
@MainActor
class TextExpansionEngine {
    private let context: NSManagedObjectContext
    private let pasteEngine: PasteEngine
    private let variableProcessor: VariableProcessor

    // Performance: Cache snippets to avoid Core Data query on every keystroke
    private var snippetCache: [CachedSnippet] = []
    private var cacheLastUpdated: Date = .distantPast
    private var cachedFrontmostApp: String = ""
    private var frontmostAppCacheTime: Date = .distantPast

    struct Match {
        let snippet: Snippet
        let abbreviationLength: Int
    }

    struct CachedSnippet {
        let snippet: Snippet
        let abbreviation: String
        let triggerType: ExpandTrigger
        let restrictToApps: Bool
        let allowedApps: [String]

        init(snippet: Snippet) {
            self.snippet = snippet
            self.abbreviation = snippet.abbreviation
            self.triggerType = snippet.expandTriggerType
            self.restrictToApps = snippet.restrictToApps
            self.allowedApps = snippet.appRules?.compactMap { $0.bundleIdentifier } ?? []
        }
    }

    init(context: NSManagedObjectContext) {
        self.context = context
        self.pasteEngine = PasteEngine()
        self.variableProcessor = VariableProcessor()
    }

    /// Refresh snippet cache from Core Data
    func refreshCache() {
        let request: NSFetchRequest<Snippet> = Snippet.fetchRequest()
        request.predicate = NSPredicate(format: "isEnabled == YES")

        guard let snippets = try? context.fetch(request) else {
            snippetCache = []
            return
        }

        // Cache snippet data for fast lookup
        snippetCache = snippets.map { CachedSnippet(snippet: $0) }
        cacheLastUpdated = Date()
        print("🔄 Snippet cache refreshed: \(snippetCache.count) snippets")
    }

    /// Get frontmost app with caching (avoid expensive call on every keystroke)
    private func getFrontmostAppBundleID() -> String {
        let now = Date()
        // Cache for 100ms - app switches don't happen faster than this
        if now.timeIntervalSince(frontmostAppCacheTime) < 0.1 {
            return cachedFrontmostApp
        }

        if let app = NSWorkspace.shared.frontmostApplication {
            cachedFrontmostApp = app.bundleIdentifier ?? ""
        } else {
            cachedFrontmostApp = ""
        }
        frontmostAppCacheTime = now
        return cachedFrontmostApp
    }

    /// Find matching snippet in the typed buffer (optimized for performance)
    nonisolated func findMatch(in buffer: String, triggerChar: Character?) -> Match? {
        // This method must be synchronous and fast - called on every keystroke
        // We use the cached data only, no Core Data queries

        return MainActor.assumeIsolated {
            // Refresh cache if empty or stale (older than 30 seconds)
            if snippetCache.isEmpty || Date().timeIntervalSince(cacheLastUpdated) > 30 {
                refreshCache()
            }

            // Get frontmost app (with caching)
            let frontmostApp = getFrontmostAppBundleID()

            // Check trigger character first
            guard let trigger = triggerChar else { return nil }

            // Buffer might include trigger char at end - strip it for matching
            let bufferWithoutTrigger = buffer.dropLast()
            guard !bufferWithoutTrigger.isEmpty else { return nil }

            // Fast path: Try to find a match in cached snippets
            for cached in snippetCache {
                let abbrev = cached.abbreviation

                // Quick check: buffer (without trigger) must end with abbreviation
                guard bufferWithoutTrigger.hasSuffix(abbrev) else { continue }

                // Check app-specific rules
                if cached.restrictToApps {
                    if !cached.allowedApps.isEmpty && !cached.allowedApps.contains(frontmostApp) {
                        continue
                    }
                }

                // Check if trigger matches the required type
                if isValidTrigger(trigger, for: cached.triggerType) {
                    return Match(snippet: cached.snippet, abbreviationLength: abbrev.count)
                }
            }

            return nil
        }
    }

    /// Expand a matched snippet (async - runs in background)
    func expand(_ match: Match, includingTrigger: Bool = false) async {
        let snippet = match.snippet

        // Delete the abbreviation + trigger character (backspaces)
        let deleteCount = match.abbreviationLength + (includingTrigger ? 1 : 0)
        deleteCharacters(count: deleteCount)

        // Small delay for deletion to complete
        try? await Task.sleep(nanoseconds: 5_000_000) // 5ms

        // Process variables in content
        let processedContent = await variableProcessor.process(snippet.content)

        // Paste the expanded text
        await pasteEngine.paste(processedContent)

        // Play sound if enabled
        if snippet.playSound {
            playExpansionSound()
        }

        // Update statistics
        updateStatistics(for: snippet)
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

    private func deleteCharacters(count: Int) {
        // Simulate backspace key presses (synchronous)
        for _ in 0..<count {
            let deleteDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x33, keyDown: true)
            let deleteUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x33, keyDown: false)

            deleteDown?.post(tap: .cghidEventTap)
            deleteUp?.post(tap: .cghidEventTap)

            // Small delay between keystrokes (busy wait for precision)
            usleep(1000) // 1ms
        }
    }

    private func playExpansionSound() {
        NSSound.beep()
    }

    private func updateStatistics(for snippet: Snippet) {
        snippet.useCount += 1
        snippet.lastUsed = Date()

        do {
            try context.save()
        } catch {
            print("❌ Failed to update snippet statistics: \(error)")
        }
    }
}
