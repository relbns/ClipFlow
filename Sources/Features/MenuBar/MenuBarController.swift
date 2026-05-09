import AppKit
import SwiftUI

/// Builds and manages the menu bar menu
@MainActor
class MenuBarController {
    private let clipboardMonitor: ClipboardMonitor

    // Settings from AppStorage
    @AppStorage("viewMode") private var viewMode = "organized"
    @AppStorage("showIcons") private var showIcons = true
    @AppStorage("showThumbnails") private var showThumbnails = true
    @AppStorage("menuItemsNumbered") private var menuItemsNumbered = true
    @AppStorage("maxTitleLength") private var maxTitleLength = 50.0

    init(clipboardMonitor: ClipboardMonitor) {
        self.clipboardMonitor = clipboardMonitor
    }

    func buildMainMenu() -> NSMenu {
        let menu = NSMenu()

        // Header with search
        if viewMode == "organized" {
            // Search field (TODO: implement search functionality)
            let searchItem = NSMenuItem()
            let searchField = NSSearchField(frame: NSRect(x: 0, y: 0, width: 200, height: 22))
            searchField.placeholderString = "Search..."
            searchItem.view = searchField
            menu.addItem(searchItem)
            menu.addItem(NSMenuItem.separator())
        }

        // Clipboard history (mode-dependent)
        if viewMode == "simple" {
            addSimpleClipboardHistory(to: menu)
        } else {
            addOrganizedClipboardHistory(to: menu)
        }

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

    // Simple mode: flat list (Flycut-style)
    private func addSimpleClipboardHistory(to menu: NSMenu) {
        let clips = clipboardMonitor.clipHistory.prefix(Int(maxTitleLength))

        if clips.isEmpty {
            let item = NSMenuItem(title: "No clipboard history", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            return
        }

        for (index, clip) in clips.enumerated() {
            let titleText = clip.content.prefix(Int(maxTitleLength)).trimmingCharacters(in: .whitespacesAndNewlines)
            let keyEquiv = menuItemsNumbered && index < 9 ? "\(index + 1)" : (index == 9 ? "0" : "")

            let item = NSMenuItem(
                title: "",
                action: #selector(pasteClip(_:)),
                keyEquivalent: keyEquiv
            )

            // Build attributed title with optional icon/number
            var displayTitle = ""
            if showIcons {
                let icon = iconForClipType(clip.type)
                displayTitle = "\(icon) "
            }
            if menuItemsNumbered && index < 10 {
                displayTitle += "\(index < 9 ? index + 1 : 0). "
            }
            displayTitle += titleText

            // Create attributed string with RTL support
            let isRTL = clip.content.isRTL
            let attributedTitle = NSMutableAttributedString(string: displayTitle)

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

            // Add image thumbnail if enabled
            if showThumbnails, clip.type == "image", let imageData = clip.imageData {
                let image = NSImage(data: imageData)
                image?.size = NSSize(width: 32, height: 32)
                item.image = image
            }

            menu.addItem(item)
        }
    }

    // Organized mode: grouped by type
    private func addOrganizedClipboardHistory(to menu: NSMenu) {
        let clips = Array(clipboardMonitor.clipHistory.prefix(30))

        if clips.isEmpty {
            let item = NSMenuItem(title: "No clipboard history", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            return
        }

        // Group by type
        var textClips: [ClipItem] = []
        var imageClips: [ClipItem] = []
        var urlClips: [ClipItem] = []

        for clip in clips {
            if clip.type == "image" {
                imageClips.append(clip)
            } else if clip.content.hasPrefix("http://") || clip.content.hasPrefix("https://") {
                urlClips.append(clip)
            } else {
                textClips.append(clip)
            }
        }

        // Add Recent section (first 5)
        let recentSubmenu = NSMenu()
        for (index, clip) in clips.prefix(5).enumerated() {
            let item = createMenuItem(for: clip, index: index)
            recentSubmenu.addItem(item)
        }
        let recentItem = NSMenuItem(title: "📌 Recent (\(min(5, clips.count)))", action: nil, keyEquivalent: "")
        recentItem.submenu = recentSubmenu
        menu.addItem(recentItem)

        // Add Images section
        if !imageClips.isEmpty {
            let imagesSubmenu = NSMenu()
            for (index, clip) in imageClips.enumerated() {
                let item = createMenuItem(for: clip, index: index)
                imagesSubmenu.addItem(item)
            }
            let imagesItem = NSMenuItem(title: "🖼️ Images (\(imageClips.count))", action: nil, keyEquivalent: "")
            imagesItem.submenu = imagesSubmenu
            menu.addItem(imagesItem)
        }

        // Add URLs section
        if !urlClips.isEmpty {
            let urlsSubmenu = NSMenu()
            for (index, clip) in urlClips.enumerated() {
                let item = createMenuItem(for: clip, index: index)
                urlsSubmenu.addItem(item)
            }
            let urlsItem = NSMenuItem(title: "🔗 URLs (\(urlClips.count))", action: nil, keyEquivalent: "")
            urlsItem.submenu = urlsSubmenu
            menu.addItem(urlsItem)
        }

        // Add Text section
        if !textClips.isEmpty {
            let textSubmenu = NSMenu()
            for (index, clip) in textClips.prefix(10).enumerated() {
                let item = createMenuItem(for: clip, index: index)
                textSubmenu.addItem(item)
            }
            let textItem = NSMenuItem(title: "📝 Text (\(textClips.count))", action: nil, keyEquivalent: "")
            textItem.submenu = textSubmenu
            menu.addItem(textItem)
        }
    }

    private func createMenuItem(for clip: ClipItem, index: Int) -> NSMenuItem {
        let titleText = clip.content.prefix(Int(maxTitleLength)).trimmingCharacters(in: .whitespacesAndNewlines)
        let keyEquiv = menuItemsNumbered && index < 9 ? "\(index + 1)" : (index == 9 ? "0" : "")

        let item = NSMenuItem(
            title: "",
            action: #selector(pasteClip(_:)),
            keyEquivalent: keyEquiv
        )

        // Create attributed string with RTL support
        let isRTL = clip.content.isRTL
        let attributedTitle = NSMutableAttributedString(string: titleText)

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

        // Add image thumbnail if enabled
        if showThumbnails, clip.type == "image", let imageData = clip.imageData {
            let image = NSImage(data: imageData)
            image?.size = NSSize(width: 24, height: 24)
            item.image = image
        }

        return item
    }

    private func iconForClipType(_ type: String) -> String {
        switch type {
        case "image": return "🖼️"
        case "url": return "🔗"
        default: return "📝"
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
