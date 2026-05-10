import AppKit
import Combine
import CoreData

/// Monitors the system clipboard for changes
@MainActor
class ClipboardMonitor: ObservableObject {
    @Published var clipHistory: [ClipItem] = []

    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let pasteboard = NSPasteboard.general
    private var cancellables = Set<AnyCancellable>()
    private let maxHistorySize = 30
    private var inMemoryContext: NSManagedObjectContext?

    init() {
        // Create in-memory context that works even if persistent store fails
        let container = NSPersistentContainer(name: "ClipFlow")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, error in
            if let error = error {
                print("⚠️ In-memory store failed: \(error)")
            }
        }

        inMemoryContext = container.viewContext
    }

    func startMonitoring() {
        lastChangeCount = pasteboard.changeCount

        // Poll every 750 milliseconds (0.75 seconds) - more reasonable than microseconds
        timer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                await self.checkClipboard()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkClipboard() async {
        let currentChangeCount = pasteboard.changeCount

        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        // Get clipboard content
        if let string = pasteboard.string(forType: .string) {
            await handleNewClip(content: string, type: .text)
        } else if let image = pasteboard.data(forType: .tiff) {
            await handleNewClip(content: "Image", type: .image, imageData: image)
        }
    }

    private func handleNewClip(content: String, type: ClipType, imageData: Data? = nil) async {
        guard let context = inMemoryContext else {
            print("⚠️ No context available for clip storage")
            return
        }

        print("📋 New clip detected: \(content.prefix(50))")

        // Check for duplicates
        let contentHash = content.sha256Hash
        if clipHistory.contains(where: { $0.dataHash == contentHash }) {
            print("   ↳ Duplicate, skipping")
            return
        }

        // Create new clip item
        let clipItem = ClipItem(context: context)
        clipItem.id = UUID()
        clipItem.content = content
        clipItem.type = type.rawValue
        clipItem.createdAt = Date()
        clipItem.dataHash = contentHash
        clipItem.isPinned = false
        clipItem.imageData = imageData

        // Add to history (newest first)
        clipHistory.insert(clipItem, at: 0)

        // Maintain max size
        if clipHistory.count > maxHistorySize {
            clipHistory = Array(clipHistory.prefix(maxHistorySize))
        }

        print("   ↳ Added to history (\(clipHistory.count) items)")
    }

    func clearHistory() {
        clipHistory.removeAll()
        print("🗑️ Clipboard history cleared")
    }
}
