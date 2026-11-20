import AppKit
import CoreData

@MainActor
final class TextExpansionEngine {
    private let context: NSManagedObjectContext
    private var buffer = TypingBuffer()
    private var candidates: [ExpansionCandidate] = []
    private var snippetIDs: [String: NSManagedObjectID] = [:]
    private var needsReload = true
    private var isExpanding = false
    private var observers: [NSObjectProtocol] = []

    init(context: NSManagedObjectContext) {
        self.context = context
        observers.append(NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextObjectsDidChange, object: context, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.needsReload = true }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.buffer.reset()
                self?.textBeforeShortcut = nil
            }
        })
    }

    /// What was typed right before the latest Command/Control shortcut, while nothing else happened since.
    private var textBeforeShortcut: String?

    func takeTextBeforeShortcut() -> String? {
        defer { textBeforeShortcut = nil }
        return textBeforeShortcut
    }

    func handle(_ event: TypingEvent) {
        if case .shortcut = event {
            if !buffer.text.isEmpty { textBeforeShortcut = buffer.text }
            buffer.reset()
            return
        }
        textBeforeShortcut = nil
        switch event {
        case .reset, .shortcut:
            buffer.reset()
        case .deleteBackward:
            buffer.deleteBackward()
        case .characters(let characters):
            guard !isExpanding else { return }
            buffer.append(characters)
            evaluate()
            if characters.contains(where: { $0 == "\r" || $0 == "\n" || $0 == "\t" }) {
                buffer.reset()
            }
        }
    }

    private func evaluate() {
        guard let target = NSWorkspace.shared.frontmostApplication,
              target.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        let bundleID = target.bundleIdentifier ?? ""
        guard !AppExclusions.expansion.contains(bundleID) else { return }

        reloadIfNeeded()
        guard let match = AbbreviationMatcher.match(buffer: buffer.text, candidates: candidates, frontmostApp: bundleID),
              let objectID = snippetIDs[match.candidateID],
              let snippet = try? context.existingObject(with: objectID) as? Snippet else { return }

        buffer.reset()
        expand(snippet, match: match, in: target)
    }

    private func expand(_ snippet: Snippet, match: AbbreviationMatch, in target: NSRunningApplication) {
        let content = snippet.content
        if SnippetTemplate.prompts(in: content).isEmpty {
            let rendered = SnippetRenderer.renderWithoutPrompts(content)
            finish(snippet, rendered: rendered, match: match)
            return
        }

        isExpanding = true
        Task { @MainActor in
            defer { self.isExpanding = false }
            guard let rendered = await SnippetRenderer.render(content, returningFocusTo: target) else { return }
            self.finish(snippet, rendered: rendered, match: match)
        }
    }

    private func finish(_ snippet: Snippet, rendered: RenderedSnippet, match: AbbreviationMatch) {
        let trailing = match.trailingText
        let output = RenderedSnippet(
            text: rendered.text + trailing,
            cursorOffsetFromEnd: rendered.cursorOffsetFromEnd > 0 ? rendered.cursorOffsetFromEnd + trailing.count : 0
        )
        PasteEngine.shared.insert(output, replacingTyped: match.deleteCount)

        if snippet.playSound || UserDefaults.standard.bool(forKey: "playSoundOnExpand") {
            NSSound(named: "Tink")?.play()
        }
        CoreDataStack.shared.recordSnippetUse(snippet.objectID)
    }

    private func reloadIfNeeded() {
        guard needsReload else { return }
        needsReload = false

        let request = Snippet.fetchRequest()
        request.predicate = NSPredicate(format: "isEnabled == YES AND (group == nil OR group.isEnabled == YES)")
        let snippets = (try? context.fetch(request)) ?? []

        snippetIDs = [:]
        candidates = snippets.map { snippet in
            let id = snippet.objectID.uriRepresentation().absoluteString
            snippetIDs[id] = snippet.objectID
            let rules = (snippet.appRules ?? []).filter(\.isEnabled)
            let allowed = Set(rules.filter { !$0.isDeny }.map(\.bundleIdentifier))
            let denied = Set(rules.filter(\.isDeny).map(\.bundleIdentifier))
            return ExpansionCandidate(
                id: id,
                abbreviation: snippet.abbreviation.trimmingCharacters(in: .whitespacesAndNewlines),
                trigger: snippet.expandTriggerType,
                caseSensitive: snippet.caseSensitive,
                allowedApps: snippet.restrictToApps && !allowed.isEmpty ? allowed : nil,
                deniedApps: denied
            )
        }
        .sorted { $0.abbreviation.count > $1.abbreviation.count }
        Log.expansion.debug("Loaded \(self.candidates.count) snippets")
    }
}
