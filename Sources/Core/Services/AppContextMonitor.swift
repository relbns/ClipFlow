import AppKit

/// Monitors the currently active application
@MainActor
class AppContextMonitor: ObservableObject {
    @Published var currentApp: RunningApp?

    private var observation: NSKeyValueObservation?

    struct RunningApp: Equatable {
        let bundleIdentifier: String
        let name: String
        let icon: NSImage?

        static func == (lhs: RunningApp, rhs: RunningApp) -> Bool {
            lhs.bundleIdentifier == rhs.bundleIdentifier
        }
    }

    func startMonitoring() {
        // Monitor active app changes
        observation = NSWorkspace.shared.observe(\.frontmostApplication, options: [.new]) { [weak self] workspace, change in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.updateCurrentApp()
            }
        }

        // Set initial app
        updateCurrentApp()
    }

    func stopMonitoring() {
        observation?.invalidate()
        observation = nil
    }

    private func updateCurrentApp() {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            currentApp = nil
            return
        }

        currentApp = RunningApp(
            bundleIdentifier: app.bundleIdentifier ?? "",
            name: app.localizedName ?? "Unknown",
            icon: app.icon
        )
    }
}
