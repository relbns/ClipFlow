import Cocoa
import Combine

/// Manages app-wide theme (light/dark/auto)
@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var currentTheme: String = "auto" {
        didSet {
            applyTheme()
        }
    }

    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Load saved preference
        currentTheme = UserDefaults.standard.string(forKey: "appearanceMode") ?? "auto"

        // Observe changes
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                let newTheme = UserDefaults.standard.string(forKey: "appearanceMode") ?? "auto"
                if self?.currentTheme != newTheme {
                    self?.currentTheme = newTheme
                }
            }
            .store(in: &cancellables)

        // Apply initial theme
        applyTheme()

    }

    private func applyTheme() {
        let appearance: NSAppearance?

        switch currentTheme {
        case "light":
            appearance = NSAppearance(named: .aqua)
        case "dark":
            appearance = NSAppearance(named: .darkAqua)
        default: // "auto"
            appearance = nil // Follow system
        }

        // App level only: a per-window appearance would also restyle the status item's window.
        NSApp.appearance = appearance
    }
}
