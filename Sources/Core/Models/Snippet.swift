import Foundation
import CoreData

@objc(Snippet)
public class Snippet: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var abbreviation: String
    @NSManaged public var content: String
    @NSManaged public var isEnabled: Bool
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date

    // Expansion settings
    @NSManaged public var expandTrigger: String // "space", "delimiter", "any"
    @NSManaged public var caseSensitive: Bool
    @NSManaged public var playSound: Bool

    // Statistics
    @NSManaged public var useCount: Int32
    @NSManaged public var lastUsed: Date?

    // Relationships
    @NSManaged public var group: SnippetGroup?
    @NSManaged public var appRules: Set<AppRule>?

    // App-specific expansion
    @NSManaged public var restrictToApps: Bool // If true, only expand in specified apps
    @NSManaged public var isFavorite: Bool
}

extension Snippet {
    var expandTriggerType: ExpandTrigger {
        ExpandTrigger(rawValue: expandTrigger) ?? .delimiter
    }

    @nonobjc class func fetchRequest() -> NSFetchRequest<Snippet> {
        return NSFetchRequest<Snippet>(entityName: "Snippet")
    }

    /// An enabled snippet with the trigger chosen in Preferences; the caller saves the context.
    static func insert(title: String, abbreviation: String, content: String, group: SnippetGroup?, in context: NSManagedObjectContext) -> Snippet {
        let snippet = Snippet(context: context)
        snippet.id = UUID()
        snippet.title = title
        snippet.abbreviation = uniqueAbbreviation(abbreviation, in: context)
        snippet.content = content
        snippet.isEnabled = true
        snippet.createdAt = Date()
        snippet.updatedAt = Date()
        snippet.expandTrigger = UserDefaults.standard.string(forKey: "expandAfter") ?? ExpandTrigger.delimiter.rawValue
        snippet.group = group
        return snippet
    }

    /// `prefix` plus three random letters, neither the start of another abbreviation nor starting with one, so with
    /// the "any character" trigger typing it never fires a shorter snippet first. When an existing abbreviation
    /// makes that impossible (say a `.clip` snippet), any unused one is returned.
    static func freshAbbreviation(prefix: String, in context: NSManagedObjectContext) -> String {
        let existing = ((try? context.fetch(fetchRequest())) ?? [])
            .map { $0.abbreviation.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        let letters = Array("abcdefghijkmnpqrstuvwxyz")
        var candidate = prefix
        for _ in 0..<200 {
            candidate = prefix + String((0..<3).map { _ in letters.randomElement()! })
            if !existing.contains(where: { $0.hasPrefix(candidate) || candidate.hasPrefix($0) }) { return candidate }
        }
        return uniqueAbbreviation(candidate, in: context)
    }

    static func uniqueAbbreviation(_ base: String, in context: NSManagedObjectContext) -> String {
        let existing = Set(((try? context.fetch(fetchRequest())) ?? []).map { $0.abbreviation.lowercased() })
        guard existing.contains(base.lowercased()) else { return base }
        var number = 2
        while existing.contains("\(base)\(number)".lowercased()) { number += 1 }
        return "\(base)\(number)"
    }
}

enum ExpandTrigger: String, Codable {
    case space
    case delimiter // space, tab, punctuation
    case any
    case tab
    case enter
}
