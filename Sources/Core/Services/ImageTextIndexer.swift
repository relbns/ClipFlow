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
            var attempted: Set<UUID> = []
            while defaults.bool(forKey: Self.enabledKey), let monitor, let next = monitor.nextImageToRecognize(),
                  attempted.insert(next.id).inserted {
                let text = await TextRecognizer.recognize(imageData: next.image, languages: TextRecognizer.currentLanguages(defaults: defaults)) ?? ""
                monitor.setRecognizedText(text, forClipID: next.id)
            }
        }
    }
}
