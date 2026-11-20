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

    /// Groups in the order the Snippet Editor shows them.
    static func ordered(in context: NSManagedObjectContext) -> [SnippetGroup] {
        let request = fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true), NSSortDescriptor(key: "createdAt", ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    /// An enabled group placed last; the caller saves the context.
    static func insert(named name: String, in context: NSManagedObjectContext) -> SnippetGroup {
        let sortOrder = (ordered(in: context).map(\.sortOrder).max() ?? 0) + 1
        let group = SnippetGroup(context: context)
        group.id = UUID()
        group.name = name
        group.isEnabled = true
        group.createdAt = Date()
        group.sortOrder = sortOrder
        return group
    }
}
