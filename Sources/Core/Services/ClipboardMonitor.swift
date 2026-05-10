import AppKit
import Combine

/// Monitors the system clipboard for changes
@MainActor
class ClipboardMonitor: ObservableObject {
    @Published var clipHistory: [ClipItem] = []

    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let pasteboard = NSPasteboard.general
    private var cancellables = Set<AnyCancellable>()

    func startMonitoring() {
        lastChangeCount = pasteboard.changeCount

        // Poll every 750 microseconds (0.00075 seconds)
        timer = Timer.scheduledTimer(withTimeInterval: 0.00075, repeats: true) { [weak self] _ in
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
        // TODO: Save to Core Data
        print("📋 New clip detected: \(content.prefix(50))")
    }

    func clearHistory() {
        clipHistory.removeAll()
    }
}
