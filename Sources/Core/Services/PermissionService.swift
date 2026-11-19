import AppKit
import Combine

/// Input Monitoring (read keystrokes) and Accessibility (post keystrokes): both are needed
/// for snippet expansion and paste-on-pick, and both APIs work inside the App Sandbox.
@MainActor
final class PermissionService: ObservableObject {
    static let shared = PermissionService()

    @Published private(set) var canListen = false
    @Published private(set) var canPost = false

    var isGranted: Bool { canListen && canPost }

    private var timer: Timer?

    private init() {
        refresh()
    }

    func refresh() {
        let listen = CGPreflightListenEventAccess() || AXIsProcessTrusted()
        let post = CGPreflightPostEventAccess() || AXIsProcessTrusted()
        if listen != canListen { canListen = listen }
        if post != canPost { canPost = post }
    }

    func startWatching() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            MainActor.assumeIsolated { PermissionService.shared.refresh() }
        }
    }

    /// Adds ClipFlow to the System Settings lists and shows the system prompts.
    func request() {
        if !canPost { _ = CGRequestPostEventAccess() }
        refresh()
        if !canListen { _ = CGRequestListenEventAccess() }
        refresh()
    }

    func openSystemSettings() {
        let pane = canPost ? "Privacy_ListenEvent" : "Privacy_Accessibility"
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}
