import Foundation
import CoreData

struct ExportedSnippet: Codable {
    let title: String
    let abbreviation: String
    let content: String
    let expandTrigger: String
    let caseSensitive: Bool
    let playSound: Bool
    let group: String?
}

struct ExportedGroup: Codable {
    let name: String
    let snippets: [ExportedSnippet]
}

/// Runs on the main actor because it works with the view context.
@MainActor
final class SnippetExporter {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    /// Export all snippets to JSON
    func exportAll() async throws -> Data {
        let request: NSFetchRequest<SnippetGroup> = SnippetGroup.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SnippetGroup.sortOrder, ascending: true)]

        guard let groups = try? context.fetch(request) else {
            throw ExportError.fetchFailed
        }

        let exportedGroups = groups.map { group in
            let snippets = group.sortedSnippets.map { snippet in
                ExportedSnippet(
                    title: snippet.title,
                    abbreviation: snippet.abbreviation,
                    content: snippet.content,
                    expandTrigger: snippet.expandTrigger,
                    caseSensitive: snippet.caseSensitive,
                    playSound: snippet.playSound,
                    group: group.name
                )
            }

            return ExportedGroup(name: group.name, snippets: snippets)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(exportedGroups)
    }

    /// Export single group to JSON
    func exportGroup(_ group: SnippetGroup) async throws -> Data {
        let snippets = group.sortedSnippets.map { snippet in
            ExportedSnippet(
                title: snippet.title,
                abbreviation: snippet.abbreviation,
                content: snippet.content,
                expandTrigger: snippet.expandTrigger,
                caseSensitive: snippet.caseSensitive,
                playSound: snippet.playSound,
                group: group.name
            )
        }

        let exportedGroup = ExportedGroup(name: group.name, snippets: snippets)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(exportedGroup)
    }

    /// Import snippets from JSON data
    func importFromJSON(_ data: Data, mergeStrategy: MergeStrategy = .skip) async throws -> ImportResult {
        try importGroups(try JSONDecoder().decode([ExportedGroup].self, from: data), mergeStrategy: mergeStrategy)
    }

    /// Adds TextExpander groups with the trigger chosen in Preferences; abbreviations already in use are skipped.
    func importTextExpander(_ parsed: TextExpanderImport.Result, defaults: UserDefaults = .standard) throws -> ImportResult {
        let trigger = defaults.string(forKey: "expandAfter") ?? ExpandTrigger.delimiter.rawValue
        let groups = parsed.groups.map { group in
            ExportedGroup(name: group.name, snippets: group.snippets.map {
                ExportedSnippet(
                    title: $0.label, abbreviation: $0.abbreviation, content: $0.content, expandTrigger: trigger,
                    caseSensitive: false, playSound: false, group: group.name
                )
            })
        }
        return try importGroups(groups, mergeStrategy: .skip)
    }

    func importGroups(_ groups: [ExportedGroup], mergeStrategy: MergeStrategy) throws -> ImportResult {
        var imported = 0
        var skipped = 0
        var conflicts: [String] = []

        for exportedGroup in groups {
            // Find or create group
            let groupRequest: NSFetchRequest<SnippetGroup> = SnippetGroup.fetchRequest()
            groupRequest.predicate = NSPredicate(format: "name == %@", exportedGroup.name)

            let existingGroups = try? context.fetch(groupRequest)
            let group: SnippetGroup

            if let existing = existingGroups?.first {
                group = existing
            } else {
                group = SnippetGroup(context: context)
                group.id = UUID()
                group.name = exportedGroup.name
                group.isEnabled = true
                group.createdAt = Date()
                group.sortOrder = Int32((try? context.count(for: SnippetGroup.fetchRequest())) ?? 0)
            }

            // Import snippets
            for exportedSnippet in exportedGroup.snippets {
                // Check for duplicates
                let snippetRequest: NSFetchRequest<Snippet> = Snippet.fetchRequest()
                snippetRequest.predicate = NSPredicate(format: "abbreviation == %@", exportedSnippet.abbreviation)

                if let existing = try? context.fetch(snippetRequest).first {
                    conflicts.append(exportedSnippet.abbreviation)

                    switch mergeStrategy {
                    case .skip:
                        skipped += 1
                        continue
                    case .overwrite:
                        context.delete(existing)
                    case .rename:
                        // Will be renamed below
                        break
                    }
                }

                let snippet = Snippet(context: context)
                snippet.id = UUID()
                snippet.title = exportedSnippet.title
                snippet.abbreviation = mergeStrategy == .rename && conflicts.contains(exportedSnippet.abbreviation)
                    ? "\(exportedSnippet.abbreviation)_imported"
                    : exportedSnippet.abbreviation
                snippet.content = exportedSnippet.content
                snippet.expandTrigger = exportedSnippet.expandTrigger
                snippet.caseSensitive = exportedSnippet.caseSensitive
                snippet.playSound = exportedSnippet.playSound
                snippet.isEnabled = true
                snippet.createdAt = Date()
                snippet.updatedAt = Date()
                snippet.useCount = 0
                snippet.group = group
                snippet.restrictToApps = false

                imported += 1
            }
        }

        try context.save()

        return ImportResult(imported: imported, skipped: skipped, conflicts: conflicts)
    }

    /// Export to TextExpander-compatible XML format
    func exportToXML() async throws -> Data {
        let request: NSFetchRequest<SnippetGroup> = SnippetGroup.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SnippetGroup.sortOrder, ascending: true)]

        guard let groups = try? context.fetch(request) else {
            throw ExportError.fetchFailed
        }

        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <array>
        """

        for group in groups {
            xml += "\n  <dict>"
            xml += "\n    <key>snippetsPlain</key>"
            xml += "\n    <array>"

            for snippet in group.sortedSnippets {
                xml += "\n      <dict>"
                xml += "\n        <key>abbreviation</key>"
                xml += "\n        <string>\(xmlEscape(snippet.abbreviation))</string>"
                xml += "\n        <key>label</key>"
                xml += "\n        <string>\(xmlEscape(snippet.title))</string>"
                xml += "\n        <key>plainText</key>"
                xml += "\n        <string>\(xmlEscape(snippet.content))</string>"
                xml += "\n      </dict>"
            }

            xml += "\n    </array>"
            xml += "\n    <key>name</key>"
            xml += "\n    <string>\(xmlEscape(group.name))</string>"
            xml += "\n  </dict>"
        }

        xml += "\n</array>\n</plist>"

        guard let data = xml.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }

        return data
    }

    private func xmlEscape(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

enum MergeStrategy {
    case skip      // Skip conflicting snippets
    case overwrite // Overwrite existing snippets
    case rename    // Rename imported snippets with _imported suffix
}

struct ImportResult {
    let imported: Int
    let skipped: Int
    let conflicts: [String]
}

enum ExportError: Error {
    case fetchFailed
    case encodingFailed
    case decodingFailed
}
