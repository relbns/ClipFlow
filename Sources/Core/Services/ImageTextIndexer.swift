import Combine
import Foundation

/// Reads the text in image clips in the background, one at a time, so search finds screenshots by their words.
@MainActor
final class ImageTextIndexer {
    static let shared = ImageTextIndexer()
    static let enabledKey = "ocrIndexImages"

    private weak var monitor: ClipboardMonitor?
    private var defaults: UserDefaults = .standard
    private var isRunning = false
    /// Clips already tried in this launch; one whose result could not be saved is not read again and again.
    private var attempted: Set<UUID> = []
    private var cancellables: Set<AnyCancellable> = []

    func start(monitor: ClipboardMonitor, defaults: UserDefaults = .standard) {
        self.monitor = monitor
        self.defaults = defaults
        cancellables = []
        monitor.$clipHistory
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.run() }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.run() }
            .store(in: &cancellables)
    }

    private func run() {
        guard !isRunning, defaults.bool(forKey: Self.enabledKey), monitor != nil else { return }
        isRunning = true
        Task {
            defer { isRunning = false }
            let languages = TextRecognizer.currentLanguages(defaults: defaults)
            while defaults.bool(forKey: Self.enabledKey), let monitor, let next = monitor.nextImageToRecognize(excluding: attempted) {
                attempted.insert(next.id)
                let text = await Self.recognize(pasteboardData: next.pasteboardData, languages: languages)
                monitor.setRecognizedText(text, forClipID: next.id)
            }
        }
    }

    /// Decodes the stored clip and reads its image off the main thread; "" when there is no image or no text.
    private static func recognize(pasteboardData: Data?, languages: [String]) async -> String {
        let image = await Task.detached(priority: .utility) { () -> Data? in
            guard let pasteboardData, let snapshot = try? PasteboardSnapshot.decoded(from: pasteboardData) else { return nil }
            return snapshot.data(for: .png) ?? snapshot.data(for: .tiff)
        }.value
        guard let image else { return "" }
        return await TextRecognizer.recognize(imageData: image, languages: languages) ?? ""
    }
}
