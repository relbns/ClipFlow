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
    /// Sensitive clips waiting for removal, by when they were copied.
    private var expiring: [UUID: Date] = [:] {
        didSet {
            let saved = Dictionary(uniqueKeysWithValues: expiring.map { ($0.key.uuidString, $0.value.timeIntervalSince1970) })
            defaults.set(saved, forKey: SensitiveText.pendingKey)
        }
    }
    private var expiryTimer: Timer?
    /// Every copy also joins the paste stack while it is on.
    var pasteStack: PasteStack?

    init(context: NSManagedObjectContext, pasteboard: NSPasteboard = .general, defaults: UserDefaults = .standard) {
        self.context = context
        self.pasteboard = pasteboard
        self.defaults = defaults
        reload()
        resumePendingRemovals()
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

        recordCopy(capture, snapshot: snapshot, sourceName: source?.localizedName, sourceBundleID: source?.bundleIdentifier)
    }

    /// Records a copy, unless it is a sensitive clip the user does not save, and schedules its removal when asked.
    private func recordCopy(_ capture: ClipCapture, snapshot: PasteboardSnapshot, sourceName: String?, sourceBundleID: String?) {
        pasteStack?.add(snapshot, preview: capture.kind == .image ? L("clip_image") : capture.text)
        let sensitive = SensitiveText.detectedKind(of: capture, defaults: defaults) != nil
        let handling = SensitiveText.handling(in: defaults)
        if sensitive, handling == .skip {
            Log.clipboard.info("Skipped a sensitive clip")
            return
        }
        let id = record(capture, snapshot: snapshot, sourceName: sourceName, sourceBundleID: sourceBundleID)
        if sensitive, handling == .expire, let id {
            scheduleRemoval(of: id, copiedAt: Date())
        }
    }

    @discardableResult
    func record(_ capture: ClipCapture, snapshot: PasteboardSnapshot, source: NSRunningApplication?) -> UUID? {
        record(capture, snapshot: snapshot, sourceName: source?.localizedName, sourceBundleID: source?.bundleIdentifier)
    }

    @discardableResult
    func record(
        _ capture: ClipCapture, snapshot: PasteboardSnapshot, sourceName: String?, sourceBundleID: String?,
        at date: Date = Date(), recognizedText: String? = nil
    ) -> UUID? {
        if removeDuplicates, let existing = fetchItem(hash: capture.hash) {
            existing.createdAt = date
            existing.sourceAppName = sourceName
            existing.sourceBundleID = sourceBundleID
            if let recognizedText { existing.recognizedText = recognizedText }
            saveAndReload()
            return existing.id
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
            item.recognizedText = recognizedText
        }

        saveAndReload()
        trimHistory()
        return item.id
    }

    // MARK: - Sensitive clips

    func scheduleRemoval(of id: UUID, copiedAt: Date) {
        expiring[id] = copiedAt
        guard expiryTimer == nil else { return }
        expiryTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.removeExpiredSensitiveClips() }
        }
    }

    /// Removes the sensitive clips whose time is up (all of them once "Don't save" is on), unless pinned or no longer
    /// detected, and empties the clipboard when asked and it still holds that text.
    func removeExpiredSensitiveClips(now: Date = Date()) {
        defer {
            if expiring.isEmpty {
                expiryTimer?.invalidate()
                expiryTimer = nil
            }
        }
        let handling = SensitiveText.handling(in: defaults)
        guard handling != .keep else {
            expiring.removeAll()
            return
        }
        let lifetime = SensitiveText.lifetime(in: defaults)
        let due = expiring.filter { handling == .skip || $0.value.addingTimeInterval(lifetime) <= now }
        guard !due.isEmpty else { return }
        for id in due.keys { expiring[id] = nil }
        let waiting = Set(expiring.keys.compactMap { fetchItem(id: $0).flatMap { $0.isPinned ? nil : Self.trimmed($0.content) } })
        let clearClipboard = handling == .expire && defaults.bool(forKey: SensitiveText.clearClipboardKey)
        var removed = false
        for id in due.keys {
            guard let item = fetchItem(id: id), !item.isPinned,
                  SensitiveText.detectedKind(of: item.content, defaults: defaults) != nil else { continue }
            let text = Self.trimmed(item.content)
            if clearClipboard, !waiting.contains(text), pasteboard.string(forType: .string).map(Self.trimmed) == text {
                pasteboard.clearContents()
                lastChangeCount = pasteboard.changeCount
            }
            context.delete(item)
            removed = true
        }
        if removed { saveAndReload() }
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Picks up the removals an earlier run had scheduled; only clips copied while removal was on are ever removed.
    private func resumePendingRemovals() {
        let saved = defaults.dictionary(forKey: SensitiveText.pendingKey) as? [String: Double] ?? [:]
        for (key, copiedAt) in saved {
            guard let id = UUID(uuidString: key) else { continue }
            scheduleRemoval(of: id, copiedAt: Date(timeIntervalSince1970: copiedAt))
        }
        removeExpiredSensitiveClips()
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

    /// Pinned clips that are text, for sync; images and files stay on their own Mac.
    func pinnedTexts() -> [(kind: ClipType, content: String)] {
        let request = ClipItem.fetchRequest()
        request.predicate = NSPredicate(format: "isPinned == YES AND type IN %@", [ClipType.text, .rtf, .url, .color].map(\.rawValue))
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        return ((try? context.fetch(request)) ?? []).map { (ClipType(rawValue: $0.type) ?? .text, $0.content) }
    }

    /// Pins the text clip with this content, recording it first when this Mac does not have it.
    func pinText(_ content: String) {
        if let item = fetchItem(content: content) {
            guard !item.isPinned else { return }
            item.isPinned = true
            saveAndReload()
            return
        }
        let snapshot = PasteboardSnapshot.text(content, transient: false)
        guard let capture = ClipCapture.classify(snapshot) else { return }
        record(capture, snapshot: snapshot, sourceName: "ClipFlow", sourceBundleID: Bundle.main.bundleIdentifier)
        if let item = fetchItem(content: content), !item.isPinned {
            item.isPinned = true
            saveAndReload()
        }
    }

    /// Unpins every clip with this text, so a duplicate left pinned does not pin it again on the other Macs.
    func unpinText(_ content: String) {
        let request = ClipItem.fetchRequest()
        request.predicate = NSPredicate(format: "content == %@ AND isPinned == YES", content)
        let items = (try? context.fetch(request)) ?? []
        guard !items.isEmpty else { return }
        for item in items { item.isPinned = false }
        saveAndReload()
    }

    private func fetchItem(content: String) -> ClipItem? {
        let request = ClipItem.fetchRequest()
        request.predicate = NSPredicate(format: "content == %@ AND type IN %@", content, [ClipType.text, .rtf, .url, .color].map(\.rawValue))
        request.sortDescriptors = [NSSortDescriptor(key: "isPinned", ascending: false)]
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    func setPinned(_ clip: SimpleClipItem, _ pinned: Bool) {
        guard let item = fetchItem(id: clip.id) else { return }
        item.isPinned = pinned
        saveAndReload()
        NotificationCenter.default.post(name: .clipPinsChanged, object: self)
    }

    /// Whether ClipFlow records history at all ("Record clipboard history" in Preferences).
    var isRecording: Bool { defaults.bool(forKey: "startMonitoring") }

    /// Records a screen capture as an image clip with the text already found in it, unless history is off.
    func recordScreenshot(_ png: Data, recognizedText: String) {
        guard isRecording else { return }
        let snapshot = PasteboardSnapshot(items: [[NSPasteboard.PasteboardType.png.rawValue: png]])
        guard let capture = ClipCapture.classify(snapshot) else { return }
        record(capture, snapshot: snapshot, sourceName: "ClipFlow", sourceBundleID: Bundle.main.bundleIdentifier, recognizedText: recognizedText)
    }

    /// Puts text ClipFlow produced (read from the screen or an image) on the clipboard and into history as ClipFlow's.
    func copy(_ text: String) {
        copyOwn(.text(text, transient: false))
    }

    /// Puts a screen capture on the clipboard as an image and into history; its text is read later only if
    /// "Find images by their text" is on.
    func copyImage(_ png: Data) {
        copyOwn(PasteboardSnapshot(items: [[NSPasteboard.PasteboardType.png.rawValue: png]]))
    }

    private func copyOwn(_ snapshot: PasteboardSnapshot) {
        let changeCount = snapshot.write(to: pasteboard)
        OwnPasteboardWrites.shared.record(changeCount)
        lastChangeCount = changeCount
        guard isRecording, let capture = ClipCapture.classify(snapshot) else { return }
        recordCopy(capture, snapshot: snapshot, sourceName: "ClipFlow", sourceBundleID: Bundle.main.bundleIdentifier)
    }

    /// "" marks an image as read with no text, so it is not read again.
    func setRecognizedText(_ text: String, forClipID id: UUID) {
        guard let item = fetchItem(id: id), item.recognizedText != text else { return }
        item.recognizedText = text
        saveAndReload()
    }

    /// The newest image clip whose text has not been read, skipping `excluded`, with its stored pasteboard data
    /// still encoded; decoding a large image happens off the main thread.
    func nextImageToRecognize(excluding excluded: Set<UUID> = []) -> (id: UUID, pasteboardData: Data?)? {
        let request = ClipItem.fetchRequest()
        request.predicate = NSPredicate(
            format: "type == %@ AND recognizedText == nil AND NOT (id IN %@)", ClipType.image.rawValue, Array(excluded)
        )
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        request.fetchLimit = 1
        guard let item = try? context.fetch(request).first else { return nil }
        return (item.id, item.pasteboardData)
    }

    func delete(_ clip: SimpleClipItem) {
        guard let item = fetchItem(id: clip.id) else { return }
        let wasPinned = item.isPinned
        context.delete(item)
        saveAndReload()
        if wasPinned { NotificationCenter.default.post(name: .clipPinsChanged, object: self) }
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
