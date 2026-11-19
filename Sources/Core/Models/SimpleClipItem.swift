import AppKit

/// A history row as the UI sees it. The full pasteboard data stays in Core Data until it is pasted.
struct SimpleClipItem: Identifiable, Hashable {
    let id: UUID
    let content: String
    let type: String
    let createdAt: Date
    let dataHash: String
    let isPinned: Bool
    /// A small thumbnail for image clips.
    let imageData: Data?
    let sourceAppName: String?
    let sourceBundleID: String?
    let byteCount: Int
    let pixelWidth: Int
    let pixelHeight: Int

    var kind: ClipType { ClipType(rawValue: type) ?? .text }

    var lineCount: Int {
        content.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).count
    }

    init(_ item: ClipItem) {
        id = item.id
        content = item.content
        type = item.type
        createdAt = item.createdAt
        dataHash = item.dataHash
        isPinned = item.isPinned
        imageData = item.imageData
        sourceAppName = item.sourceAppName
        sourceBundleID = item.sourceBundleID
        byteCount = Int(item.byteCount)
        pixelWidth = Int(item.pixelWidth)
        pixelHeight = Int(item.pixelHeight)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SimpleClipItem, rhs: SimpleClipItem) -> Bool {
        lhs.id == rhs.id && lhs.createdAt == rhs.createdAt && lhs.isPinned == rhs.isPinned
    }
}

/// What a pasteboard snapshot holds, reduced to what history shows and dedupes on.
struct ClipCapture: Equatable {
    let kind: ClipType
    let text: String
    let hash: String
    let byteCount: Int
    let pixelWidth: Int
    let pixelHeight: Int

    private static let hexColor = try! NSRegularExpression(pattern: #"^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$"#)

    static func classify(_ snapshot: PasteboardSnapshot) -> ClipCapture? {
        let byteCount = snapshot.byteCount
        let hash = snapshot.contentHash

        if let fileURLData = snapshot.data(for: .fileURL),
           let urlString = String(data: fileURLData, encoding: .utf8),
           let url = URL(string: urlString) {
            return ClipCapture(kind: .file, text: url.path, hash: hash, byteCount: byteCount, pixelWidth: 0, pixelHeight: 0)
        }

        if let text = snapshot.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let kind: ClipType
            if hexColor.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
                kind = .color
            } else if isWebURL(trimmed) {
                kind = .url
            } else if snapshot.contains(.rtf) || snapshot.contains(.html) {
                kind = .rtf
            } else {
                kind = .text
            }
            return ClipCapture(kind: kind, text: text, hash: hash, byteCount: byteCount, pixelWidth: 0, pixelHeight: 0)
        }

        if let imageData = snapshot.data(for: .png) ?? snapshot.data(for: .tiff),
           let rep = NSBitmapImageRep(data: imageData) {
            return ClipCapture(kind: .image, text: "", hash: hash, byteCount: imageData.count, pixelWidth: rep.pixelsWide, pixelHeight: rep.pixelsHigh)
        }
        return nil
    }

    static func isWebURL(_ text: String) -> Bool {
        guard !text.contains(where: \.isWhitespace),
              let url = URL(string: text),
              let scheme = url.scheme?.lowercased() else { return false }
        return (scheme == "http" || scheme == "https") && url.host != nil
    }
}

extension SimpleClipItem {
    /// The first line of a history row.
    @MainActor
    var title: String {
        switch kind {
        case .image:
            return pixelWidth > 0 ? L("clip_image_size", pixelWidth, pixelHeight) : L("clip_image")
        case .file:
            return URL(fileURLWithPath: content).lastPathComponent
        default:
            let firstLine = content.trimmingCharacters(in: .whitespacesAndNewlines)
                .split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
            return String(firstLine.prefix(80))
        }
    }

    /// The second line of a history row, from the clip's real data.
    @MainActor
    func subtitle(now: Date = Date()) -> String {
        let detail: String
        switch kind {
        case .image:
            let size = ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
            detail = pixelWidth > 0 ? "\(pixelWidth)×\(pixelHeight) · \(size)" : size
        case .color:
            detail = L("clip_hex_color")
        case .file:
            detail = L("clip_file")
        default:
            detail = lineCount > 1 ? L("clip_lines", lineCount) : Self.copiedAgo(createdAt, now: now)
        }
        guard let app = sourceAppName, !app.isEmpty else { return detail }
        return "\(detail) • \(app)"
    }

    @MainActor
    static func copiedAgo(_ date: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        switch seconds {
        case ..<60: return L("copied_seconds_ago", seconds)
        case ..<3600: return L("copied_minutes_ago", seconds / 60)
        case ..<86400: return L("copied_hours_ago", seconds / 3600)
        default: return L("copied_days_ago", seconds / 86400)
        }
    }
}
