import AppKit
import CoreData

@MainActor
final class ClipboardMonitor: ObservableObject {
    @Published private(set) var clipHistory: [SimpleClipItem] = []

    private let context: NSManagedObjectContext
    private let pasteboard: NSPasteboard
    private var timer: Timer?
    private var lastChangeCount = 0
    private let thumbnailSize: CGFloat = 64

    private let defaults: UserDefaults
    private var maxHistoryItems: Int { max(10, defaults.integer(forKey: "maxHistoryItems")) }
    private var removeDuplicates: Bool { defaults.bool(forKey: "removeDuplicates") }
    private var moveUsedToTop: Bool { defaults.bool(forKey: "moveUsedToTop") }

    init(context: NSManagedObjectContext, pasteboard: NSPasteboard = .general, defaults: UserDefaults = .standard) {
        self.context = context
        self.pasteboard = pasteboard
        self.defaults = defaults
        reload()
    }

    func startMonitoring() {
        guard timer == nil else { return }
        lastChangeCount = pasteboard.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkPasteboard() }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func checkPasteboard() {
        guard timer != nil else { return }
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount
        guard !OwnPasteboardWrites.shared.contains(changeCount) else { return }

        let source = NSWorkspace.shared.frontmostApplication
        if let bundleID = source?.bundleIdentifier, AppExclusions.history.contains(bundleID) { return }

        guard let snapshot = PasteboardSnapshot.capture(from: pasteboard) else {
            Log.clipboard.info("Skipped a clip larger than the history limit")
            return
        }
        guard !snapshot.isEmpty, !snapshot.isPrivate, let capture = ClipCapture.classify(snapshot) else { return }

        record(capture, snapshot: snapshot, source: source)
    }

    func record(_ capture: ClipCapture, snapshot: PasteboardSnapshot, source: NSRunningApplication?) {
        record(capture, snapshot: snapshot, sourceName: source?.localizedName, sourceBundleID: source?.bundleIdentifier)
    }

    func record(_ capture: ClipCapture, snapshot: PasteboardSnapshot, sourceName: String?, sourceBundleID: String?, at date: Date = Date()) {
        if removeDuplicates, let existing = fetchItem(hash: capture.hash) {
            existing.createdAt = date
            existing.sourceAppName = sourceName
            existing.sourceBundleID = sourceBundleID
            saveAndReload()
            return
        }

        let item = ClipItem(context: context)
        item.id = UUID()
        item.createdAt = date
        item.type = capture.kind.rawValue
        item.content = capture.text
        item.dataHash = capture.hash
        item.isPinned = false
        item.byteCount = Int64(capture.byteCount)
        item.pixelWidth = Int32(capture.pixelWidth)
        item.pixelHeight = Int32(capture.pixelHeight)
        item.sourceAppName = sourceName
        item.sourceBundleID = sourceBundleID
        item.pasteboardData = try? snapshot.encoded()
        if capture.kind == .image {
            item.imageData = thumbnail(from: snapshot)
        }

        saveAndReload()
        trimHistory()
    }

    /// The pasteboard contents to put back when the user picks this clip.
    func snapshot(for clip: SimpleClipItem) -> PasteboardSnapshot? {
        guard let item = fetchItem(id: clip.id) else { return nil }
        if let data = item.pasteboardData, let snapshot = try? PasteboardSnapshot.decoded(from: data) {
            return snapshot
        }
        return .text(item.content, transient: false)
    }

    func markUsed(_ clip: SimpleClipItem) {
        guard moveUsedToTop, let item = fetchItem(id: clip.id) else { return }
        item.createdAt = Date()
        saveAndReload()
    }

    func setPinned(_ clip: SimpleClipItem, _ pinned: Bool) {
        guard let item = fetchItem(id: clip.id) else { return }
        item.isPinned = pinned
        saveAndReload()
    }

    /// Records a screen capture as an image clip with the text already found in it.
    func recordScreenshot(_ png: Data, recognizedText: String) {
        let snapshot = PasteboardSnapshot(items: [[NSPasteboard.PasteboardType.png.rawValue: png]])
        guard let capture = ClipCapture.classify(snapshot) else { return }
        record(capture, snapshot: snapshot, sourceName: "ClipFlow", sourceBundleID: Bundle.main.bundleIdentifier)
        guard let item = fetchItem(hash: capture.hash) else { return }
        item.recognizedText = recognizedText
        saveAndReload()
    }

    /// "" marks an image as read with no text, so it is not read again.
    func setRecognizedText(_ text: String, forClipID id: UUID) {
        guard let item = fetchItem(id: id), item.recognizedText != text else { return }
        item.recognizedText = text
        saveAndReload()
    }

    /// The newest image clip whose text has not been read yet, with its full image.
    func nextImageToRecognize() -> (id: UUID, image: Data)? {
        let request = ClipItem.fetchRequest()
        request.predicate = NSPredicate(format: "type == %@ AND recognizedText == nil", ClipType.image.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        guard let items = try? context.fetch(request) else { return nil }
        for item in items {
            if let data = item.pasteboardData, let snapshot = try? PasteboardSnapshot.decoded(from: data),
               let image = snapshot.data(for: .png) ?? snapshot.data(for: .tiff) {
                return (item.id, image)
            }
            item.recognizedText = ""
        }
        if context.hasChanges { saveAndReload() }
        return nil
    }

    func delete(_ clip: SimpleClipItem) {
        guard let item = fetchItem(id: clip.id) else { return }
        context.delete(item)
        saveAndReload()
    }

    /// Pinned clips survive a clear.
    func clearHistory() {
        let request = ClipItem.fetchRequest()
        request.predicate = NSPredicate(format: "isPinned != YES")
        for item in (try? context.fetch(request)) ?? [] {
            context.delete(item)
        }
        saveAndReload()
    }

    // MARK: - Storage

    private func trimHistory() {
        let request = ClipItem.fetchRequest()
        request.predicate = NSPredicate(format: "isPinned != YES")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        let unpinned = (try? context.fetch(request)) ?? []
        guard unpinned.count > maxHistoryItems else { return }
        for item in unpinned.dropFirst(maxHistoryItems) {
            context.delete(item)
        }
        saveAndReload()
    }

    private func reload() {
        let request = ClipItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        clipHistory = ((try? context.fetch(request)) ?? []).map(SimpleClipItem.init)
    }

    private func saveAndReload() {
        do {
            try context.save()
        } catch {
            Log.clipboard.error("Could not save history: \(error.localizedDescription, privacy: .public)")
            context.rollback()
        }
        reload()
    }

    private func fetchItem(id: UUID) -> ClipItem? {
        let request = ClipItem.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func fetchItem(hash: String) -> ClipItem? {
        let request = ClipItem.fetchRequest()
        request.predicate = NSPredicate(format: "dataHash == %@", hash)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func thumbnail(from snapshot: PasteboardSnapshot) -> Data? {
        guard let data = snapshot.data(for: .png) ?? snapshot.data(for: .tiff),
              let image = NSImage(data: data) else { return nil }
        let scale = min(1, thumbnailSize / max(image.size.width, image.size.height, 1))
        let size = NSSize(width: max(1, image.size.width * scale), height: max(1, image.size.height * scale))
        let thumbnail = NSImage(size: size)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size))
        thumbnail.unlockFocus()
        guard let tiff = thumbnail.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
