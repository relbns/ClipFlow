import AppKit

/// Builds and manages the menu bar menu
@MainActor
class MenuBarController {
    private let clipboardMonitor: ClipboardMonitor

    init(clipboardMonitor: ClipboardMonitor) {
        self.clipboardMonitor = clipboardMonitor
    }

    func buildMainMenu() -> NSMenu {
        let menu = NSMenu()

        // Header
        let headerItem = NSMenuItem(title: "ClipFlow", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        menu.addItem(NSMenuItem.separator())

        // Clipboard history
        addClipboardHistory(to: menu)

        menu.addItem(NSMenuItem.separator())

        // Actions
        menu.addItem(NSMenuItem(
            title: "Snippet Editor...",
            action: #selector(openSnippetEditor),
            keyEquivalent: "e"
        ))

        menu.addItem(NSMenuItem(
            title: "Preferences...",
            action: #selector(openPreferences),
            keyEquivalent: ","
        ))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(
            title: "Clear History",
            action: #selector(clearHistory),
            keyEquivalent: ""
        ))

        menu.addItem(NSMenuItem(
            title: "Quit ClipFlow",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        return menu
    }

    private func addClipboardHistory(to menu: NSMenu) {
        let clips = clipboardMonitor.clipHistory.prefix(10)

        if clips.isEmpty {
            let item = NSMenuItem(title: "No clipboard history", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            return
        }

        for (index, clip) in clips.enumerated() {
            let title = clip.content.prefix(50).trimmingCharacters(in: .whitespacesAndNewlines)
            let keyEquiv = index < 9 ? "\(index + 1)" : ""

            let item = NSMenuItem(
                title: "",
                action: #selector(pasteClip(_:)),
                keyEquivalent: keyEquiv
            )

            // Create attributed string with RTL support
            let isRTL = clip.content.isRTL
            let attributedTitle = NSMutableAttributedString(string: title)

            if isRTL {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .right
                paragraphStyle.baseWritingDirection = .rightToLeft

                attributedTitle.addAttribute(
                    .paragraphStyle,
                    value: paragraphStyle,
                    range: NSRange(location: 0, length: attributedTitle.length)
                )
            }

            item.attributedTitle = attributedTitle
            item.representedObject = clip
            menu.addItem(item)
        }
    }

    @objc private func pasteClip(_ sender: NSMenuItem) {
        guard let clip = sender.representedObject as? ClipItem else { return }

        Task {
            let pasteEngine = PasteEngine()
            await pasteEngine.paste(clip.content)
        }
    }

    @objc private func clearHistory() {
        clipboardMonitor.clearHistory()
    }

    @objc private func openPreferences() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openSnippetEditor() {
        // TODO: Implement snippet editor window
        print("📝 Opening snippet editor...")
    }
}
