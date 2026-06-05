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

        print("🎨 ThemeManager initialized with theme: \(currentTheme)")
    }

    private func applyTheme() {
        let appearance: NSAppearance?

        switch currentTheme {
        case "light":
            appearance = NSAppearance(named: .aqua)
            print("🎨 Applying Light theme")
        case "dark":
            appearance = NSAppearance(named: .darkAqua)
            print("🎨 Applying Dark theme")
        default: // "auto"
            appearance = nil // Follow system
            print("🎨 Applying Auto theme (system default)")
        }

        NSApp.appearance = appearance

        // Notify all windows to update
        for window in NSApp.windows {
            window.appearance = appearance
        }
    }
}
