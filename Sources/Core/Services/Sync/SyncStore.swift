import CoreData
import CryptoKit
import Foundation
import KeyboardShortcuts

/// Turns this Mac's snippets, groups, pinned text and settings into sync records, and applies records from
/// other Macs. Usage counts and per-Mac choices (history recording, launch at login) stay local.
@MainActor
final class SyncStore {
    static let settingKeys = [
        "textExpansionEnabled", "expandAfter", "playSoundOnExpand", "viewMode", "appearanceMode",
        "closePopoverOnOutsideClick", "layoutFixSwitchesKeyboard", "alwaysPastePlainText", "maxHistoryItems",
        "removeDuplicates", "moveUsedToTop", AppExclusions.defaultsKey, TextRecognizer.languagesKey,
        ImageTextIndexer.enabledKey, ScreenCapture.saveScreenshotsKey, LanguageManager.choiceKey,
        SensitiveText.handlingKey, SensitiveText.minutesKey, SensitiveText.clearClipboardKey,
        PasteStack.orderKey, PasteStack.endsWhenEmptyKey
    ] + SensitiveKind.allCases.map(\.defaultsKey)
    static let shortcutNames: [KeyboardShortcuts.Name] = [
        .showHistoryMenu, .fixKeyboardLayout, .pastePlainText, .captureScreenText, .captureScreenImage,
        .togglePasteStack, .pasteNextFromStack, .showSnippetEditor, .clearHistory
    ]

    private let context: NSManagedObjectContext
    private weak var monitor: ClipboardMonitor?
    private let defaults: UserDefaults
    /// Values the user set, without registered defaults; a new Mac's defaults must not overwrite real choices.
    private let explicitSettings: () -> [String: Any]

    init(context: NSManagedObjectContext, monitor: ClipboardMonitor?, defaults: UserDefaults = .standard,
         explicitSettings: @escaping () -> [String: Any] = { UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "") ?? [:] }) {
        self.context = context
        self.monitor = monitor
        self.defaults = defaults
        self.explicitSettings = explicitSettings
    }

    // MARK: - Export

    func export(kinds: Set<String>) -> [String: JSONValue] {
        var records: [String: JSONValue] = [:]
        if kinds.contains("group") || kinds.contains("snippet") {
            for group in SnippetGroup.ordered(in: context) {
                records["group:\(group.id.uuidString)"] = .object([
                    "name": .string(group.name), "isEnabled": .bool(group.isEnabled), "sortOrder": .number(Double(group.sortOrder))
                ])
            }
            for snippet in (try? context.fetch(Snippet.fetchRequest())) ?? [] {
                records["snippet:\(snippet.id.uuidString)"] = Self.payload(of: snippet)
            }
        }
        if kinds.contains("pin"), let monitor {
            for pin in monitor.pinnedTexts() {
                // The text alone: another Mac records the pin as plain text, so a type here would never match there.
                records["pin:\(Self.pinID(pin.content))"] = .object(["content": .string(pin.content)])
            }
        }
        if kinds.contains("setting") {
            let explicit = explicitSettings()
            for key in Self.settingKeys {
                if let value = explicit[key].flatMap(Self.json) { records["setting:\(key)"] = value }
            }
            for name in Self.shortcutNames {
                let key = "KeyboardShortcuts_\(name.rawValue)"
                if let value = explicit[key].flatMap(Self.json) { records["setting:\(key)"] = value }
            }
        }
        return records
    }

    private static func payload(of snippet: Snippet) -> JSONValue {
        let rules = (snippet.appRules ?? []).sorted { $0.bundleIdentifier < $1.bundleIdentifier }.map { rule -> JSONValue in
            .object([
                "bundleID": .string(rule.bundleIdentifier), "appName": .string(rule.appName),
                "isDeny": .bool(rule.isDeny), "isEnabled": .bool(rule.isEnabled)
            ])
        }
        return .object([
            "group": snippet.group.map { .string($0.id.uuidString) } ?? .null,
            "title": .string(snippet.title),
            "abbreviation": .string(snippet.abbreviation),
            "content": .string(snippet.content),
            "isEnabled": .bool(snippet.isEnabled),
            "expandTrigger": .string(snippet.expandTrigger),
            "caseSensitive": .bool(snippet.caseSensitive),
            "playSound": .bool(snippet.playSound),
            "restrictToApps": .bool(snippet.restrictToApps),
            "isFavorite": .bool(snippet.isFavorite),
            "appRules": .array(rules)
        ])
    }

    static func pinID(_ content: String) -> String {
        SHA256.hash(data: Data(content.utf8)).prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    private static func json(_ value: Any) -> JSONValue? {
        switch value {
        case let bool as Bool where CFGetTypeID(value as CFTypeRef) == CFBooleanGetTypeID(): return .bool(bool)
        case let number as NSNumber: return .number(number.doubleValue)
        case let string as String: return .string(string)
        default: return nil
        }
    }

    // MARK: - Joining

    /// The snippets' edit times, so a Mac joining a folder again keeps edits made since it last synced. A starter
    /// still exactly as created has none: its install time would otherwise beat edits and deletions made on the
    /// other Macs long before.
    func snippetEditTimes() -> [String: Date] {
        var times: [String: Date] = [:]
        for snippet in (try? context.fetch(Snippet.fetchRequest())) ?? [] where !StarterSnippets.isPristine(snippet) {
            times["snippet:\(snippet.id.uuidString)"] = snippet.updatedAt
        }
        return times
    }

    /// Gives untouched starter snippets from an older install their fixed ids; see `StarterSnippets.adoptFixedIDs`.
    func adoptStarterIDs() -> Bool {
        StarterSnippets.adoptFixedIDs(in: context)
        return save()
    }

    // MARK: - Apply

    struct ApplyResult {
        let saved: Bool
        /// Snippets whose group has not arrived yet (its Mac's file is still downloading); tried again next time.
        let deferred: Set<String>
        /// Snippets taken out of a group another Mac deleted. That is not an edit made here, so it must not be
        /// published as one, or this Mac's older copy could beat a later edit on a third Mac.
        let detached: Set<String>
    }

    /// Snippets and groups that sync applied, as they stand afterwards, with the time they were made. Every channel
    /// (this Mac's library, each shared group) sees them: another channel publishes such a change at that time, not
    /// as a new edit, so a newer edit elsewhere still wins.
    static var applied: [String: (payload: JSONValue?, time: Date)] = [:]

    /// Snippets and groups are saved first; pins and settings, which are written elsewhere, only after that save
    /// succeeds, so a failed sync leaves nothing half applied.
    func apply(_ records: [SyncRecord], deletedGroups: Set<String>) -> ApplyResult {
        var deferred: Set<String> = []
        var detached: Set<String> = []
        for record in records where record.kind == "group" {
            detached.formUnion(applyGroup(id: SyncMerge.id(of: record.key), record: record))
        }
        for record in records where record.kind == "snippet" {
            // Filed under a group that was deleted: kept without it, which is not an edit made here either.
            let groupID = record.payload?["group"]?.string
            let orphaned = groupID.map { deletedGroups.contains($0) && group(id: $0) == nil } ?? false
            if !applySnippet(id: SyncMerge.id(of: record.key), record: record, deletedGroups: deletedGroups) {
                deferred.insert(record.key)
            } else if orphaned, !record.deleted {
                detached.insert(record.key)
            }
        }
        guard save() else { return ApplyResult(saved: false, deferred: deferred, detached: detached) }
        let local = export(kinds: ["group", "snippet"])
        for record in records where (record.kind == "group" || record.kind == "snippet") && !deferred.contains(record.key) {
            Self.applied[record.key] = (local[record.key], record.modifiedAt)
        }
        for record in records where record.kind == "pin" { applyPin(record) }
        for record in records where record.kind == "setting" { applySetting(key: SyncMerge.id(of: record.key), record: record) }
        return ApplyResult(saved: true, deferred: deferred, detached: detached)
    }

    /// Returns the keys of snippets a deleted group leaves without a group.
    private func applyGroup(id: String, record: SyncRecord) -> Set<String> {
        if record.deleted {
            // Snippets carry their own records: one deleted with the group arrives as its own deletion, and one
            // edited here since stays, out of the group.
            guard let group = group(id: id) else { return [] }
            let keys = Set(group.snippets.map { "snippet:\($0.id.uuidString)" })
            for snippet in group.snippets { snippet.group = nil }
            context.delete(group)
            return keys
        }
        guard let payload = record.payload, let uuid = UUID(uuidString: id) else { return [] }
        let group = group(id: id) ?? {
            let created = SnippetGroup(context: context)
            created.id = uuid
            created.createdAt = record.modifiedAt
            created.isEnabled = true
            created.sortOrder = Int32(SnippetGroup.ordered(in: context).count)
            return created
        }()
        group.name = payload["name"]?.string ?? group.name
        group.isEnabled = payload["isEnabled"]?.bool ?? group.isEnabled
        group.sortOrder = Int32(payload["sortOrder"]?.number ?? Double(group.sortOrder))
        return []
    }

    /// False when the snippet's group is not here yet, so it is not filed under no group by mistake. A group that
    /// was deleted is not coming, so such a snippet is kept without a group.
    private func applySnippet(id: String, record: SyncRecord, deletedGroups: Set<String>) -> Bool {
        if record.deleted {
            if let snippet = snippet(id: id) { context.delete(snippet) }
            return true
        }
        guard let payload = record.payload, let uuid = UUID(uuidString: id) else { return true }
        let groupID = payload["group"]?.string
        let targetGroup = groupID.flatMap { group(id: $0) }
        if let groupID, targetGroup == nil, !deletedGroups.contains(groupID) { return false }
        let existing = snippet(id: id)
        let snippet = existing ?? {
            let created = Snippet(context: context)
            created.id = uuid
            created.createdAt = record.modifiedAt
            return created
        }()
        snippet.title = payload["title"]?.string ?? ""
        snippet.abbreviation = payload["abbreviation"]?.string ?? ""
        snippet.content = payload["content"]?.string ?? ""
        // A shared group's records leave out what stays each person's own; then the value here is kept.
        snippet.isEnabled = payload["isEnabled"]?.bool ?? existing?.isEnabled ?? true
        snippet.expandTrigger = payload["expandTrigger"]?.string ?? ExpandTrigger.delimiter.rawValue
        snippet.caseSensitive = payload["caseSensitive"]?.bool ?? false
        snippet.playSound = payload["playSound"]?.bool ?? existing?.playSound ?? false
        snippet.restrictToApps = payload["restrictToApps"]?.bool ?? existing?.restrictToApps ?? false
        snippet.isFavorite = payload["isFavorite"]?.bool ?? existing?.isFavorite ?? false
        snippet.updatedAt = record.modifiedAt
        snippet.group = targetGroup
        if case .array(let rules)? = payload["appRules"] {
            for rule in snippet.appRules ?? [] { context.delete(rule) }
            for rule in rules {
                let created = AppRule.create(
                    in: context, bundleID: rule["bundleID"]?.string ?? "", appName: rule["appName"]?.string ?? "",
                    isDeny: rule["isDeny"]?.bool ?? false
                )
                created.isEnabled = rule["isEnabled"]?.bool ?? true
                created.snippet = snippet
            }
        }
        return true
    }

    private func applyPin(_ record: SyncRecord) {
        guard let monitor else { return }
        if record.deleted {
            if let content = monitor.pinnedTexts().first(where: { Self.pinID($0.content) == SyncMerge.id(of: record.key) })?.content {
                monitor.unpinText(content)
            }
        } else if let content = record.payload?["content"]?.string {
            monitor.pinText(content)
        }
    }

    private func applySetting(key: String, record: SyncRecord) {
        if key.hasPrefix("KeyboardShortcuts_") {
            guard let name = Self.shortcutNames.first(where: { "KeyboardShortcuts_\($0.rawValue)" == key }) else { return }
            if record.deleted {
                KeyboardShortcuts.reset(name)
            } else if let text = record.payload?.string, let data = text.data(using: .utf8),
                      let shortcut = try? JSONDecoder().decode(KeyboardShortcuts.Shortcut.self, from: data) {
                KeyboardShortcuts.setShortcut(shortcut, for: name)
            } else if record.payload?.bool == false {
                KeyboardShortcuts.setShortcut(nil, for: name)
            }
            return
        }
        guard Self.settingKeys.contains(key) else { return }
        if key == LanguageManager.choiceKey {
            LanguageManager.shared.setLanguage(record.deleted ? "system" : record.payload?.string ?? "system")
            return
        }
        switch record.payload {
        case .bool(let value)?: defaults.set(value, forKey: key)
        case .number(let value)?: defaults.set(value, forKey: key)
        case .string(let value)?: defaults.set(value, forKey: key)
        default: if record.deleted { defaults.removeObject(forKey: key) }
        }
    }

    // MARK: - Lookup

    private func snippet(id: String) -> Snippet? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        let request = Snippet.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func group(id: String) -> SnippetGroup? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        let request = SnippetGroup.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    @discardableResult
    private func save() -> Bool {
        guard context.hasChanges else { return true }
        do {
            try context.save()
            return true
        } catch {
            context.rollback()
            Log.storage.error("Sync could not save: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
