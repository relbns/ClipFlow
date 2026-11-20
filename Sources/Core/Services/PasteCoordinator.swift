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
        let ownWindow = NSApp.keyWindow.flatMap { $0.styleMask.contains(.titled) ? $0 : nil }
        target = ownWindow == nil ? lastOtherApp.flatMap { $0.isTerminated ? nil : $0 } : nil
        Log.ui.info("Popover opened over ClipFlow; window \(ownWindow?.title ?? "none", privacy: .public), paste target \(self.target?.bundleIdentifier ?? "ClipFlow's key window", privacy: .public)")
    }

    func forgetFrontmostApp() {
        isPopoverOpen = false
    }

    /// After a close without a pick, gives focus back to the app the popover opened over, so ClipFlow is not left in front.
    func returnFocus() {
        guard NSApp?.isActive == true, let target, !target.isTerminated else { return }
        target.activate()
    }

    enum PasteStyle: Equatable {
        case original
        case plainText
        case transformed(TextTransform)
    }

    func paste(_ clip: SimpleClipItem, as style: PasteStyle = .original) {
        guard let monitor = clipboardMonitor else { return }
        let alwaysPlain = UserDefaults.standard.bool(forKey: "alwaysPastePlainText") && clip.hasPlainText
        let snapshot: PasteboardSnapshot
        switch style == .original && alwaysPlain ? .plainText : style {
        case .original:
            guard let stored = monitor.snapshot(for: clip) else {
                Log.ui.error("Picked clip has no stored content; nothing pasted")
                return
            }
            snapshot = stored
        case .plainText:
            snapshot = .text(clip.content, transient: false)
        case .transformed(let transform):
            guard let text = transform.apply(clip.content, layoutPairs: LayoutFixer.shared.layoutPairs) else {
                NSSound.beep()
                return
            }
            snapshot = .text(text, transient: false)
        }
        closePopover()
        let target = target
        Log.ui.info("Pasting a picked clip into \(target?.bundleIdentifier ?? "ClipFlow's key window", privacy: .public)")
        Task { @MainActor in
            await PasteEngine.shared.paste(snapshot, into: target)
            monitor.markUsed(clip)
        }
    }

    /// The plain-text hotkey: pastes the clipboard's text into the frontmost app and puts the clipboard back.
    func pasteClipboardAsPlainText() async {
        guard await SyntheticKeyboard.modifiersReleased(),
              let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            NSSound.beep()
            return
        }
        PasteEngine.shared.insert(RenderedSnippet(text: text, cursorOffsetFromEnd: 0), replacingTyped: 0)
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
