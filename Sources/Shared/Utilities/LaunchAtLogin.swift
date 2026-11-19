import AppKit
import ServiceManagement

/// Launch at login through SMAppService, telling the user when macOS refuses or wants approval.
@MainActor
enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// Returns the state after the change.
    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Log.app.error("Launch at login change failed: \(error.localizedDescription, privacy: .public)")
            let alert = NSAlert()
            alert.messageText = L("launch_at_login_failed")
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
        if enabled && SMAppService.mainApp.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
        return isEnabled
    }
}
