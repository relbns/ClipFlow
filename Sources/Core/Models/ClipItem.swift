import Foundation
import CoreData
import CryptoKit

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
    @NSManaged public var pasteboardData: Data?
    @NSManaged public var sourceAppName: String?
    @NSManaged public var sourceBundleID: String?
    @NSManaged public var byteCount: Int64
    @NSManaged public var pixelWidth: Int32
    @NSManaged public var pixelHeight: Int32

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ClipItem> {
        NSFetchRequest<ClipItem>(entityName: "ClipItem")
    }
}

enum ClipType: String, Codable {
    case text
    case image
    case file
    case url
    case rtf
    case color
}

extension String {
    var sha256Hash: String {
        SHA256.hash(data: Data(utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
