import AppKit

/// Paste-on-pick from the popover: close it, return focus to the app that was in front, paste there.
@MainActor
final class PasteCoordinator {
    static let shared = PasteCoordinator()

    weak var clipboardMonitor: ClipboardMonitor?
    var closePopover: () -> Void = {}
    private var target: NSRunningApplication?

    /// Call just before the popover opens, while the user's app is still frontmost.
    func rememberFrontmostApp() {
        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            target = front
        }
    }

    func paste(_ clip: SimpleClipItem) {
        guard let monitor = clipboardMonitor, let snapshot = monitor.snapshot(for: clip) else { return }
        closePopover()
        let target = target
        Task { @MainActor in
            await PasteEngine.shared.paste(snapshot, into: target)
            monitor.markUsed(clip)
        }
    }

    func insert(_ snippet: Snippet) {
        let content = snippet.content
        closePopover()
        let target = target
        Task { @MainActor in
            guard let rendered = await SnippetRenderer.render(content, returningFocusTo: target) else { return }
            await PasteEngine.shared.insert(rendered, into: target)
            snippet.useCount += 1
            snippet.lastUsed = Date()
            CoreDataStack.shared.save()
        }
    }
}
