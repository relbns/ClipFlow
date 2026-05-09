import Foundation
import CoreData

@objc(SnippetGroup)
public class SnippetGroup: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var isEnabled: Bool
    @NSManaged public var sortOrder: Int32
    @NSManaged public var createdAt: Date

    // Sync metadata
    @NSManaged public var syncLocation: String? // "local", "icloud", "gist"
    @NSManaged public var gistId: String?
    @NSManaged public var lastSynced: Date?

    // Relationships
    @NSManaged public var snippets: Set<Snippet>
}

extension SnippetGroup {
    var sortedSnippets: [Snippet] {
        snippets.sorted { ($0.title) < ($1.title) }
    }

    @nonobjc class func fetchRequest() -> NSFetchRequest<SnippetGroup> {
        return NSFetchRequest<SnippetGroup>(entityName: "SnippetGroup")
    }
}
