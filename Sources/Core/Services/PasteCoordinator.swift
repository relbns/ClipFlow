import AppKit

/// Paste-on-pick from the popover: close it, return focus to the app that was in front, paste there.
@MainActor
final class PasteCoordinator {
    static let shared = PasteCoordinator()

    weak var clipboardMonitor: ClipboardMonitor?
    var closePopover: () -> Void = {}
    private var target: NSRunningApplication?
    private var lastOtherApp: NSRunningApplication?
    private var isPopoverOpen = false

    private init() {
        let front = NSWorkspace.shared.frontmostApplication
        lastOtherApp = front?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : front
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                guard let self, let app, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
                self.lastOtherApp = app
                // A popover that stays open follows the user to another app; the paste goes there.
                if self.isPopoverOpen { self.target = app }
            }
        }
    }

    /// Call just before the popover opens. When ClipFlow itself is in front with one of its windows, the paste goes
    /// to that window; with none (the popover was just closed), it goes to the app used before.
    func rememberFrontmostApp() {
        isPopoverOpen = true
        let front = NSWorkspace.shared.frontmostApplication
        guard front?.processIdentifier == ProcessInfo.processInfo.processIdentifier else {
            target = front
            lastOtherApp = front
            return
        }
        let ownWindow = NSApp.windows.first { $0.isVisible && $0.styleMask.contains(.titled) }
        target = ownWindow == nil ? lastOtherApp : nil
        Log.ui.info("Popover opened over ClipFlow; window \(ownWindow?.title ?? "none", privacy: .public), paste target \(self.target?.bundleIdentifier ?? "ClipFlow's key window", privacy: .public)")
    }

    func forgetFrontmostApp() {
        isPopoverOpen = false
    }

    func paste(_ clip: SimpleClipItem) {
        guard let monitor = clipboardMonitor, let snapshot = monitor.snapshot(for: clip) else {
            Log.ui.error("Picked clip has no stored content; nothing pasted")
            return
        }
        closePopover()
        let target = target
        Log.ui.info("Pasting a picked clip into \(target?.bundleIdentifier ?? "ClipFlow's key window", privacy: .public)")
        Task { @MainActor in
            await PasteEngine.shared.paste(snapshot, into: target)
            monitor.markUsed(clip)
        }
    }

    func insert(_ snippet: Snippet) {
        let content = snippet.content
        let snippetID = snippet.objectID
        closePopover()
        let target = target
        Task { @MainActor in
            guard let rendered = await SnippetRenderer.render(content, returningFocusTo: target) else { return }
            await PasteEngine.shared.insert(rendered, into: target)
            CoreDataStack.shared.recordSnippetUse(snippetID)
        }
    }
}
