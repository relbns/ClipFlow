import Foundation
import CoreData

@objc(ClipItem)
public class ClipItem: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var content: String
    @NSManaged public var type: String
    @NSManaged public var createdAt: Date
    @NSManaged public var dataHash: String
    @NSManaged public var isPinned: Bool

    // Optional properties
    @NSManaged public var imageData: Data?
    @NSManaged public var rtfData: Data?
    @NSManaged public var fileURLs: [String]?
}

extension ClipItem {
    static func create(in context: NSManagedObjectContext, content: String, type: ClipType) -> ClipItem {
        let item = ClipItem(context: context)
        item.id = UUID()
        item.content = content
        item.type = type.rawValue
        item.createdAt = Date()
        item.dataHash = content.sha256Hash
        item.isPinned = false
        return item
    }
}

enum ClipType: String, Codable {
    case text
    case image
    case file
    case url
    case rtf
}

extension String {
    var sha256Hash: String {
        // Simple hash for now - will use CryptoKit later
        return String(self.hashValue)
    }
}
