import AppKit
import CoreData
import SwiftUI

/// `--render-snapshots <folder>` renders the screens in light and dark with the design's sample data,
/// on an in-memory store and throwaway defaults; `--render-icon <folder>` writes the app icon set.
@MainActor
enum SnapshotRenderer {
    static func runIfRequested() -> Bool {
        let arguments = CommandLine.arguments
        if let flag = arguments.firstIndex(of: "--render-icon"), arguments.indices.contains(flag + 1) {
            renderIconSet(to: URL(fileURLWithPath: arguments[flag + 1], isDirectory: true))
            return true
        }
        guard let flag = arguments.firstIndex(of: "--render-snapshots"), arguments.indices.contains(flag + 1) else {
            return false
        }
        let folder = URL(fileURLWithPath: arguments[flag + 1], isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        renderAll(to: folder)
        return true
    }

    private static func arguments(after flag: String) -> String? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    private static func renderAll(to folder: URL) {
        let stack = CoreDataStack(storeURL: nil)
        let suite = "clipflow-snapshots"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        AppDefaults.register(in: defaults)
        let monitor = ClipboardMonitor(context: stack.viewContext, defaults: defaults)
        SampleData.fill(stack.viewContext, monitor: monitor)
        PopoverNavigation.shared.clipboardMonitor = monitor
        PopoverNavigation.shared.context = stack.viewContext
        PopoverNavigation.shared.defaults = defaults
        PopoverNavigation.shared.reloadSnippets()

        let languages = arguments(after: "--languages")?.split(separator: ",").map(String.init) ?? ["en"]
        for language in languages {
        LanguageManager.shared.preview(language)
        let rtl = LanguageManager.shared.layoutDirection == .rightToLeft
        for dark in [true, false] {
            let suffix = (dark ? "d" : "l") + (language == "en" ? "" : "-\(language)")
            func save<V: View>(_ name: String, _ view: V, size: CGSize?) {
                let themed = view
                    .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
                    .environment(\.locale, Locale(identifier: language))
                    .environmentObject(LanguageManager.shared)
                    .cfAutoTheme()
                    .environment(\.managedObjectContext, stack.viewContext)
                    .environment(\.colorScheme, dark ? .dark : .light)
                    .defaultAppStorage(defaults)
                render(themed, size: size, dark: dark, to: folder.appendingPathComponent("\(name)-\(suffix).png"))
            }

            defaults.set("simple", forKey: "viewMode")
            save("mb-simple", MenuBarPopover(clipboardMonitor: monitor, isPresented: .constant(true)), size: nil)
            defaults.set("organized", forKey: "viewMode")
            save("mb-org", MenuBarPopover(clipboardMonitor: monitor, isPresented: .constant(true)), size: nil)
            PopoverNavigation.shared.drilledCategory = .links
            save("mb-org-links", MenuBarPopover(clipboardMonitor: monitor, isPresented: .constant(true)), size: nil)
            PopoverNavigation.shared.drilledCategory = nil
            PopoverNavigation.shared.showsAllSnippets = true
            save("mb-org-snippets", MenuBarPopover(clipboardMonitor: monitor, isPresented: .constant(true)), size: nil)
            PopoverNavigation.shared.showsAllSnippets = false
            PopoverNavigation.shared.searchText = "sig"
            save("mb-search", MenuBarPopover(clipboardMonitor: monitor, isPresented: .constant(true)), size: nil)
            PopoverNavigation.shared.searchText = ""
            save("prefs-exp", SettingsView(initialTab: 2), size: CGSize(width: 760, height: 620))
            save("onboarding", WelcomeView(isPresented: .constant(true), onGetStarted: {}), size: CGSize(width: 780, height: 520))
            save("about", AboutView(), size: CGSize(width: 560, height: 680))
            save("snip-edit", SnippetEditorView(), size: CGSize(width: 1080, height: 700))
            save("tokens", ThemeTokenSheet(), size: nil)
            for (index, tab) in ["general", "appearance", "expansion", "hotkeys", "backup", "privacy", "language", "image-text"].enumerated() where index != 2 {
                save("prefs-\(tab)", SettingsView(initialTab: index), size: CGSize(width: 760, height: 620))
            }
        }
        }
        Log.app.info("Rendered snapshots to \(folder.path, privacy: .public)")
    }

    /// Writes an `.iconset` folder: the brand mark on Apple's icon grid (an 824pt tile on a 1024pt canvas).
    private static func renderIconSet(to folder: URL) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for points in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let pixels = CGFloat(points * scale)
                let icon = ZStack {
                    ClipFlowMark(size: pixels * 824 / 1024)
                        .shadow(color: .black.opacity(0.3), radius: pixels * 10 / 1024, y: pixels * 10 / 1024)
                }
                .frame(width: pixels, height: pixels)
                let renderer = ImageRenderer(content: icon)
                renderer.scale = 1
                guard let image = renderer.cgImage else { continue }
                let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
                let bitmap = NSBitmapImageRep(cgImage: image)
                try? bitmap.representation(using: .png, properties: [:])?.write(to: folder.appendingPathComponent(name))
            }
        }
    }

    private static func render<V: View>(_ view: V, size: CGSize?, dark: Bool, to url: URL) {
        let host = NSHostingView(rootView: view)
        let fitting = size ?? host.fittingSize
        let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: -20_000, y: -20_000), size: fitting),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.contentView = host
        host.frame = CGRect(origin: .zero, size: fitting)
        window.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))

        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        window.orderOut(nil)
        try? bitmap.representation(using: .png, properties: [:])?.write(to: url)
    }
}

/// Every theme token and palette color next to its name, for checking against the prototype's CSS.
private struct ThemeTokenSheet: View {
    @Environment(\.cfTheme) private var theme

    var body: some View {
        let rows: [(String, Color)] = [
            ("surface", theme.surface), ("surfaceAlt", theme.surfaceAlt), ("surfaceDeep", theme.surfaceDeep),
            ("textStrong", theme.textStrong), ("text", theme.text), ("textMuted", theme.textMuted), ("textLabel", theme.textLabel),
            ("fill1", theme.fill1), ("fill2", theme.fill2), ("stroke", theme.stroke),
            ("accent", theme.accent), ("success", theme.success), ("warning", theme.warning), ("danger", theme.danger),
            ("recent", BrandPalette.Category.recent), ("images", BrandPalette.Category.images), ("links", BrandPalette.Category.links),
            ("colors", BrandPalette.Category.colors), ("text cat.", BrandPalette.Category.text),
            ("tab general", BrandPalette.SettingsTab.general), ("tab hotkeys", BrandPalette.SettingsTab.hotkeys),
            ("tab sync", BrandPalette.SettingsTab.sync), ("tab language", BrandPalette.SettingsTab.language)
        ]
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 16) {
                ForEach([16, 28, 48, 96], id: \.self) { size in ClipFlowMark(size: CGFloat(size)) }
                ClipFlowMark(size: 48, rounded: false)
            }
            .padding(.bottom, 8)
            let icons: [CFIcon.IconType] = [.search, .clock, .image, .text, .link, .swatch, .bolt, .star, .pin, .folder, .chevron, .chevronDown, .plus, .cmd, .gear, .trash, .power, .cloud, .check, .circle, .key, .sparkles, .bracket, .arrowDown, .lock, .dot, .hebrew, .info]
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(64)), count: 7), spacing: 10) {
                ForEach(icons, id: \.self) { icon in
                    VStack(spacing: 4) {
                        CFIcon(type: icon, size: 22, stroke: 1.6).foregroundColor(theme.text)
                        Text(String(describing: icon)).font(.system(size: 9)).foregroundColor(theme.textMuted)
                    }
                }
            }
            .padding(.bottom, 8)
            ForEach(rows, id: \.0) { name, color in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 4).fill(color).frame(width: 44, height: 18)
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(theme.stroke, lineWidth: 1))
                    Text(name).font(.system(size: 12, design: .monospaced)).foregroundColor(theme.text)
                }
            }
        }
        .padding(20)
        .background(theme.surface)
    }
}

/// The sample rows and snippets shown in the design's artboards.
@MainActor
private enum SampleData {
    static func fill(_ context: NSManagedObjectContext, monitor: ClipboardMonitor) {
        let now = Date()
        let clips: [(String, String?, TimeInterval)] = [
            ("Apt 4B, 221B Baker Street, London", nil, 3600),
            ("48.8566° N, 2.3522° E", nil, 3000),
            ("https://figma.com/file/Xc9/ClipFlow", "Figma", 180),
            ("ronen.benami@example.com", "Slack", 900),
            ("Order #A-10847 confirmed", nil, 840),
            ("const result = await fetch(url)\nconst data = await result.json()\nreturn data", "Xcode", 420),
            ("#FF5733", "Figma", 240),
            ("Thanks for the quick turnaround — I’ll review the PR this afternoon.", "Mail", 120),
            ("https://github.com/relbns/ClipFlow", "Safari", 12)
        ]
        for (text, app, age) in clips {
            let snapshot = PasteboardSnapshot.text(text, transient: false)
            if let capture = ClipCapture.classify(snapshot) {
                monitor.record(capture, snapshot: snapshot, sourceName: app, sourceBundleID: nil, at: now.addingTimeInterval(-age))
            }
        }
        if let order = monitor.clipHistory.first(where: { $0.content.hasPrefix("Order #") }) {
            monitor.setPinned(order, true)
        }

        let groups: [(String, [(String, String, String)])] = [
            ("Personal", [("Email signature", ".sig", "Best,\nRonen Ben-Ami\nProduct Engineer · ClipFlow\nm: {prompt:Phone}\nw: clipflow.app\n\nSent on {date:EEEE, MMM d} at {time:HH:mm}{cursor}"),
                          ("Address — home", ".addr", "Apt 4B, 221B Baker Street, London"),
                          ("Today's date", ".dd", "{date:EEEE, MMM d}")]),
            ("Code", [("React component scaffold", ".rfc", "export function {prompt:Name}() {\n  return {cursor}\n}"),
                      ("console.log", ".log", "console.log({cursor})"),
                      ("Swift property wrapper", ".pw", "@propertyWrapper\nstruct {prompt:Name} {}")]),
            ("Hebrew · עברית", [("חתימה", ";חת", "בברכה,\nרונן")]),
            ("Customer support", [("Thanks", ".ty", "Thanks for reaching out!")])
        ]
        for (order, (name, snippets)) in groups.enumerated() {
            let group = SnippetGroup(context: context)
            group.id = UUID()
            group.name = name
            group.isEnabled = true
            group.createdAt = now
            group.sortOrder = Int32(order)
            for (title, abbreviation, content) in snippets {
                let snippet = Snippet(context: context)
                snippet.id = UUID()
                snippet.title = title
                snippet.abbreviation = abbreviation
                snippet.content = content
                snippet.isEnabled = true
                snippet.createdAt = now
                snippet.updatedAt = now
                snippet.useCount = title == "Email signature" ? 184 : 3
                snippet.group = group
            }
        }
        try? context.save()
    }
}
