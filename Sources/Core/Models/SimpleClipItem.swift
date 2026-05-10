import Foundation

/// Simple in-memory clip item (doesn't require Core Data)
struct SimpleClipItem: Identifiable, Hashable {
    let id: UUID
    let content: String
    let type: String
    let createdAt: Date
    let dataHash: String
    let isPinned: Bool
    let imageData: Data?

    init(
        id: UUID = UUID(),
        content: String,
        type: ClipType,
        createdAt: Date = Date(),
        imageData: Data? = nil
    ) {
        self.id = id
        self.content = content
        self.type = type.rawValue
        self.createdAt = createdAt
        self.dataHash = content.sha256Hash
        self.isPinned = false
        self.imageData = imageData
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SimpleClipItem, rhs: SimpleClipItem) -> Bool {
        lhs.id == rhs.id
    }
}
