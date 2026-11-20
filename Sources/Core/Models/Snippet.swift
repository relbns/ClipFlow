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
