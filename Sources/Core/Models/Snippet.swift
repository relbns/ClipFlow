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
}

extension Snippet {
    var expandTriggerType: ExpandTrigger {
        ExpandTrigger(rawValue: expandTrigger) ?? .delimiter
    }
}

enum ExpandTrigger: String, Codable {
    case space
    case delimiter // space, tab, punctuation
    case any
    case tab
    case enter
}
