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
        ImageTextIndexer.enabledKey, ScreenCapture.saveScreenshotsKey, LanguageManager.choiceKey
    ]
    static let shortcutNames: [KeyboardShortcuts.Name] = [
        .showHistoryMenu, .fixKeyboardLayout, .pastePlainText, .captureScreenText, .captureScreenImage,
        .showSnippetEditor, .clearHistory
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
                records["pin:\(Self.pinID(pin.content))"] = .object(["content": .string(pin.content), "type": .string(pin.kind.rawValue)])
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

    // MARK: - First join

    /// Drops this Mac's copies of snippets another Mac already has, and moves the snippets of a group another Mac
    /// has under the same name into that group once it arrives.
    func applyFirstJoin(dropSnippets: Set<String>, groupMap: [String: String]) -> [String: String] {
        for key in dropSnippets {
            if let snippet = snippet(id: SyncMerge.id(of: key)) { context.delete(snippet) }
        }
        save()
        return groupMap
    }

    func foldGroups(_ groupMap: [String: String]) {
        for (localID, remoteID) in groupMap {
            guard let local = group(id: localID), let remote = group(id: remoteID), local != remote else { continue }
            for snippet in local.snippets { snippet.group = remote }
            context.delete(local)
        }
        save()
    }

    // MARK: - Apply

    func apply(_ records: [SyncRecord]) {
        let ordered = records.sorted { order($0.kind) < order($1.kind) }
        for record in ordered {
            let id = SyncMerge.id(of: record.key)
            switch record.kind {
            case "group": applyGroup(id: id, record: record)
            case "snippet": applySnippet(id: id, record: record)
            case "pin": applyPin(record)
            case "setting": applySetting(key: id, record: record)
            default: break
            }
        }
        save()
    }

    private func order(_ kind: String) -> Int { ["group": 0, "snippet": 1, "pin": 2, "setting": 3][kind] ?? 4 }

    private func applyGroup(id: String, record: SyncRecord) {
        if record.deleted {
            if let group = group(id: id) {
                for snippet in group.snippets { context.delete(snippet) }
                context.delete(group)
            }
            return
        }
        guard let payload = record.payload, let uuid = UUID(uuidString: id) else { return }
        let group = group(id: id) ?? {
            let created = SnippetGroup(context: context)
            created.id = uuid
            created.createdAt = record.modifiedAt
            return created
        }()
        group.name = payload["name"]?.string ?? group.name
        group.isEnabled = payload["isEnabled"]?.bool ?? true
        group.sortOrder = Int32(payload["sortOrder"]?.number ?? Double(group.sortOrder))
    }

    private func applySnippet(id: String, record: SyncRecord) {
        if record.deleted {
            if let snippet = snippet(id: id) { context.delete(snippet) }
            return
        }
        guard let payload = record.payload, let uuid = UUID(uuidString: id) else { return }
        let snippet = snippet(id: id) ?? {
            let created = Snippet(context: context)
            created.id = uuid
            created.createdAt = record.modifiedAt
            return created
        }()
        snippet.title = payload["title"]?.string ?? ""
        snippet.abbreviation = payload["abbreviation"]?.string ?? ""
        snippet.content = payload["content"]?.string ?? ""
        snippet.isEnabled = payload["isEnabled"]?.bool ?? true
        snippet.expandTrigger = payload["expandTrigger"]?.string ?? ExpandTrigger.delimiter.rawValue
        snippet.caseSensitive = payload["caseSensitive"]?.bool ?? false
        snippet.playSound = payload["playSound"]?.bool ?? false
        snippet.restrictToApps = payload["restrictToApps"]?.bool ?? false
        snippet.isFavorite = payload["isFavorite"]?.bool ?? false
        snippet.updatedAt = record.modifiedAt
        snippet.group = payload["group"]?.string.flatMap { group(id: $0) }
        for rule in snippet.appRules ?? [] { context.delete(rule) }
        if case .array(let rules)? = payload["appRules"] {
            for rule in rules {
                let created = AppRule.create(
                    in: context, bundleID: rule["bundleID"]?.string ?? "", appName: rule["appName"]?.string ?? "",
                    isDeny: rule["isDeny"]?.bool ?? false
                )
                created.isEnabled = rule["isEnabled"]?.bool ?? true
                created.snippet = snippet
            }
        }
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
        if key == LanguageManager.choiceKey, let choice = record.payload?.string {
            LanguageManager.shared.setLanguage(choice)
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

    private func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            context.rollback()
            Log.storage.error("Sync could not save: \(error.localizedDescription, privacy: .public)")
        }
    }
}
