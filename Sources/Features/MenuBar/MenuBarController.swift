import AppKit
import SwiftUI

/// Builds and manages the menu bar menu
@MainActor
class MenuBarController {
    private let clipboardMonitor: ClipboardMonitor
    private weak var appDelegate: AppDelegate?

    // Settings from AppStorage
    @AppStorage("viewMode") private var viewMode = "organized"
    @AppStorage("showIcons") private var showIcons = true
    @AppStorage("showThumbnails") private var showThumbnails = true
    @AppStorage("menuItemsNumbered") private var menuItemsNumbered = true
    @AppStorage("maxTitleLength") private var maxTitleLength = 50.0

    init(clipboardMonitor: ClipboardMonitor, appDelegate: AppDelegate) {
        self.clipboardMonitor = clipboardMonitor
        self.appDelegate = appDelegate
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
        let snippetEditorItem = NSMenuItem(
            title: "Snippet Editor...",
            action: #selector(openSnippetEditor),
            keyEquivalent: "e"
        )
        snippetEditorItem.target = self
        menu.addItem(snippetEditorItem)

        let preferencesItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(openPreferences),
            keyEquivalent: ","
        )
        preferencesItem.target = self
        menu.addItem(preferencesItem)

        menu.addItem(NSMenuItem.separator())

        let clearHistoryItem = NSMenuItem(
            title: "Clear History",
            action: #selector(clearHistory),
            keyEquivalent: ""
        )
        clearHistoryItem.target = self
        menu.addItem(clearHistoryItem)

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
            item.target = self

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
            // Add color swatch for hex colors
            else if showThumbnails, let color = extractHexColor(from: clip.content) {
                let colorImage = NSImage(size: NSSize(width: 32, height: 32))
                colorImage.lockFocus()
                color.setFill()
                NSBezierPath(roundedRect: NSRect(x: 4, y: 4, width: 24, height: 24), xRadius: 6, yRadius: 6).fill()
                NSColor.black.withAlphaComponent(0.2).setStroke()
                NSBezierPath(roundedRect: NSRect(x: 4, y: 4, width: 24, height: 24), xRadius: 6, yRadius: 6).stroke()
                colorImage.unlockFocus()
                item.image = colorImage
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
        item.target = self

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
        // Add color swatch for hex colors
        else if showThumbnails, let color = extractHexColor(from: clip.content) {
            let colorImage = NSImage(size: NSSize(width: 24, height: 24))
            colorImage.lockFocus()
            color.setFill()
            NSBezierPath(roundedRect: NSRect(x: 2, y: 2, width: 20, height: 20), xRadius: 4, yRadius: 4).fill()
            NSColor.black.withAlphaComponent(0.2).setStroke()
            NSBezierPath(roundedRect: NSRect(x: 2, y: 2, width: 20, height: 20), xRadius: 4, yRadius: 4).stroke()
            colorImage.unlockFocus()
            item.image = colorImage
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

    private func extractHexColor(from text: String) -> NSColor? {
        // Match #RGB, #RGBA, #RRGGBB, #RRGGBBAA
        let pattern = #"#([0-9A-Fa-f]{3,8})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }

        let hexString = (text as NSString).substring(with: match.range(at: 1))

        // Convert hex to color
        var hex = hexString
        if hex.count == 3 {
            // RGB -> RRGGBB
            hex = String(hex.map { "\($0)\($0)" }.joined())
        }

        guard hex.count == 6 || hex.count == 8 else { return nil }

        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)

        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0
        let a = hex.count == 8 ? CGFloat((rgb >> 24) & 0xFF) / 255.0 : 1.0

        return NSColor(red: r, green: g, blue: b, alpha: a)
    }

    @objc private func pasteClip(_ sender: NSMenuItem) {
        guard let clip = sender.representedObject as? ClipItem else { return }

        Task {
            let pasteEngine = PasteEngine()
            await pasteEngine.paste(clip.content)
        }
    }

    @objc func clearHistory() {
        print("🗑️ Clear history called")
        clipboardMonitor.clearHistory()
    }

    @objc func openPreferences() {
        print("⚙️ Open preferences called")
        // Forward to AppDelegate
        if let appDelegate = appDelegate {
            print("✅ Got AppDelegate, calling openPreferences()")
            appDelegate.openPreferences()
        } else {
            print("❌ AppDelegate is nil")
        }
    }

    @objc func openSnippetEditor() {
        print("📝 Open snippet editor called")
        // Forward to AppDelegate
        if let appDelegate = appDelegate {
            print("✅ Got AppDelegate, calling openSnippetEditor()")
            appDelegate.openSnippetEditor()
        } else {
            print("❌ AppDelegate is nil")
        }
    }
}
