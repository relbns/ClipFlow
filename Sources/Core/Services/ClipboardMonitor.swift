import AppKit
import Combine

/// Monitors the system clipboard for changes
@MainActor
class ClipboardMonitor: ObservableObject {
    @Published var clipHistory: [SimpleClipItem] = []

    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let pasteboard = NSPasteboard.general
    private var cancellables = Set<AnyCancellable>()

    // Settings
    @AppStorage("maxHistoryItems") private var maxHistoryItems: Double = 30
    @AppStorage("removeDuplicates") private var removeDuplicates: Bool = true

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
        print("📋 New clip detected: \(content.prefix(50))")

        // Check for duplicates (if enabled)
        if removeDuplicates {
            let contentHash = content.sha256Hash
            if clipHistory.contains(where: { $0.dataHash == contentHash }) {
                print("   ↳ Duplicate, skipping")
                return
            }
        }

        // Create new clip item
        let clipItem = SimpleClipItem(
            content: content,
            type: type,
            imageData: imageData
        )

        // Add to history (newest first)
        clipHistory.insert(clipItem, at: 0)

        // Maintain max size (use setting)
        let maxSize = Int(maxHistoryItems)
        if clipHistory.count > maxSize {
            clipHistory = Array(clipHistory.prefix(maxSize))
        }

        print("   ↳ Added to history (\(clipHistory.count) items)")
    }

    func clearHistory() {
        clipHistory.removeAll()
        print("🗑️ Clipboard history cleared")
    }
}
