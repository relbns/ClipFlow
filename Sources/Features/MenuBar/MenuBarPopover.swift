import SwiftUI
import CoreData

/// Modern SwiftUI MenuBar Popover - replaces NSMenu
@MainActor
struct MenuBarPopover: View {
    let clipboardMonitor: ClipboardMonitor
    @Binding var isPresented: Bool

    @AppStorage("viewMode") private var viewMode = "organized"
    @State private var searchText = ""
    @State private var snippetCount: Int = 0

    @Environment(\.cfTheme) var theme

    var body: some View {
        VStack(spacing: 0) {
            // Header with Search
            headerView

            Divider()

            // Content based on mode
            ScrollView {
                switch viewMode {
                case "simple":
                    SimpleHistoryView(
                        clips: filteredClips,
                        onSelect: selectClip
                    )
                case "hebrew":
                    HebrewHistoryView(
                        clips: filteredClips,
                        onSelect: selectClip
                    )
                default: // organized
                    OrganizedHistoryView(
                        clips: filteredClips,
                        snippetCount: snippetCount,
                        onSelect: selectClip
                    )
                }
            }
            .frame(minHeight: 400, maxHeight: 700)

            Divider()

            // Footer
            footerView
        }
        .frame(width: 340)
        .background(theme.popoverBg)
        .onAppear {
            fetchSnippetCount()
        }
    }

    // MARK: - Header
    private var headerView: some View {
        VStack(spacing: 0) {
            // Search - padding 8px 8px 6px
            CFInput(
                text: $searchText,
                placeholder: "Search clips & snippets",
                prefix: AnyView(
                    CFIcon(type: .search, size: 13, stroke: 1.8)
                        .foregroundColor(theme.textSubtle)
                ),
                suffix: AnyView(
                    CFKBD(text: "⌘F", dim: true)
                )
            )
            .padding(EdgeInsets(top: 8, leading: 8, bottom: 6, trailing: 8))
        }
    }


    // MARK: - Footer
    private var footerView: some View {
        VStack(spacing: 0) {
            Divider()

            CFFooterRowBtn(icon: .sparkles, label: "Snippet Editor…", kbd: "⌘E") {
                openSnippetEditor()
            }

            CFFooterRowBtn(icon: .gear, label: "Preferences…", kbd: "⌘,") {
                openPreferences()
            }

            Divider()

            CFFooterRowBtn(icon: .trash, label: "Clear history") {
                Task { @MainActor in
                    clearClipboardHistory()
                }
            }

            CFFooterRowBtn(icon: .power, label: "Quit ClipFlow", kbd: "⌘Q", danger: true) {
                NSApp.terminate(nil)
            }

            // Mode toggle (only in Organized mode)
            if viewMode == "organized" {
                modeSwitcher
                    .padding(EdgeInsets(top: 6, leading: 10, bottom: 10, trailing: 10))
            } else {
                Spacer()
                    .frame(height: 6)
            }
        }
    }

    private var modeSwitcher: some View {
        HStack(spacing: 2) {
            ForEach(["Simple", "Organized"], id: \.self) { mode in
                Button(action: {
                    viewMode = mode.lowercased()
                }) {
                    Group {
                        if viewMode == mode.lowercased() {
                            Text(mode)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(theme.textStrong)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                                .background(theme.segSelected)
                                .cornerRadius(5)
                                .shadow(
                                    color: theme.segShadow.color,
                                    radius: theme.segShadow.radius,
                                    x: theme.segShadow.x,
                                    y: theme.segShadow.y
                                )
                        } else {
                            Text(mode)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(theme.textMuted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                                .background(Color.clear)
                                .cornerRadius(5)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(theme.inputBg)
        .cornerRadius(7)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(theme.strokeSoft, lineWidth: 1)
        )
    }

    // MARK: - Helpers
    private var filteredClips: [SimpleClipItem] {
        let clips = clipboardMonitor.clipHistory

        if searchText.isEmpty {
            return Array(clips.prefix(30))
        }

        return clips.filter { clip in
            clip.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func selectClip(_ clip: SimpleClipItem) {
        Task {
            let pasteEngine = PasteEngine()
            await pasteEngine.paste(clip.content)
            isPresented = false
        }
    }

    private func openSnippetEditor() {
        isPresented = false
        NotificationCenter.default.post(name: NSNotification.Name("OpenSnippetEditor"), object: nil)
    }

    private func openPreferences() {
        isPresented = false
        NotificationCenter.default.post(name: NSNotification.Name("OpenPreferences"), object: nil)
    }

    @MainActor
    private func clearClipboardHistory() {
        clipboardMonitor.clearHistory()
        isPresented = false
    }

    private func fetchSnippetCount() {
        let context = CoreDataStack.shared.viewContext
        let request: NSFetchRequest<Snippet> = Snippet.fetchRequest()
        request.predicate = NSPredicate(format: "isEnabled == YES")

        snippetCount = (try? context.count(for: request)) ?? 0
    }
}

// MARK: - Simple History View
struct SimpleHistoryView: View {
    let clips: [SimpleClipItem]
    let onSelect: (SimpleClipItem) -> Void

    @Environment(\.cfTheme) var theme

    var body: some View {
        VStack(spacing: 0) {
            if clips.isEmpty {
                emptyState
            } else {
                // Section Header
                HStack {
                    Text("RECENT CLIPS")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(theme.textLabel)
                        .textCase(.uppercase)
                        .tracking(0.06 * 10.5)

                    Spacer()

                    Text("\(clips.count) items")
                        .font(.system(size: 10.5))
                        .foregroundColor(theme.textSubtle)
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 4)

                // Clip List
                VStack(spacing: 2) {
                    ForEach(Array(clips.prefix(10).enumerated()), id: \.element.id) { index, clip in
                        ClipRow(
                            clip: clip,
                            index: index,
                            showNumber: true,
                            showMetadata: true,
                            onSelect: { onSelect(clip) }
                        )
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .padding(EdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            CFIcon(type: .clock, size: 32, stroke: 1.4)
                .foregroundColor(theme.textFaint)

            Text("No clipboard history")
                .font(.system(size: 13))
                .foregroundColor(theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Organized History View
struct OrganizedHistoryView: View {
    let clips: [SimpleClipItem]
    let snippetCount: Int
    let onSelect: (SimpleClipItem) -> Void

    @Environment(\.cfTheme) var theme

    private var groupedClips: (recent: [SimpleClipItem], images: [SimpleClipItem], links: [SimpleClipItem], colors: [SimpleClipItem], text: [SimpleClipItem]) {
        var recent: [SimpleClipItem] = []
        var images: [SimpleClipItem] = []
        var links: [SimpleClipItem] = []
        var colors: [SimpleClipItem] = []
        var text: [SimpleClipItem] = []

        for clip in clips {
            // Recent (first 5)
            if recent.count < 5 {
                recent.append(clip)
            }

            // Categorize
            if clip.type == "image" {
                images.append(clip)
            } else if clip.content.hasPrefix("http://") || clip.content.hasPrefix("https://") {
                links.append(clip)
            } else if clip.content.hasPrefix("#") && clip.content.count <= 9 {
                colors.append(clip)
            } else {
                text.append(clip)
            }
        }

        return (recent, images, links, colors, text)
    }

    var body: some View {
        VStack(spacing: 0) {
            let groups = groupedClips
            let pinnedClips = clips.filter { $0.isPinned }

            // PINNED Section
            if !pinnedClips.isEmpty {
                CFSectionLabel("PINNED")
                    .padding(.horizontal, 8)
                    .padding(.top, 8)

                VStack(spacing: 2) {
                    ForEach(Array(pinnedClips.prefix(2).enumerated()), id: \.element.id) { index, clip in
                        ClipRow(
                            clip: clip,
                            index: index,
                            showNumber: false,
                            showMetadata: true,
                            onSelect: { onSelect(clip) }
                        )
                    }
                }
                .padding(.bottom, 4)
            }

            // CATEGORIES Section Label
            CFSectionLabel("CATEGORIES")
                .padding(.horizontal, 8)
                .padding(.top, pinnedClips.isEmpty ? 8 : 8)

            VStack(spacing: 2) {
                CategoryGroup(
                    icon: .clock,
                    iconColor: Color(red: 0.78, green: 0.14, blue: 0.70),
                    label: "Recent",
                    count: groups.recent.count,
                    clips: groups.recent,
                    onSelect: onSelect
                )

                if !groups.images.isEmpty {
                    CategoryGroup(
                        icon: .image,
                        iconColor: Color(red: 0.74, green: 0.14, blue: 0.60),
                        label: "Images",
                        count: groups.images.count,
                        clips: groups.images,
                        onSelect: onSelect
                    )
                }

                if !groups.links.isEmpty {
                    CategoryGroup(
                        icon: .link,
                        iconColor: Color(red: 0.78, green: 0.14, blue: 0.50),
                        label: "Links",
                        count: groups.links.count,
                        clips: groups.links,
                        onSelect: onSelect
                    )
                }

                if !groups.colors.isEmpty {
                    CategoryGroup(
                        icon: .swatch,
                        iconColor: Color(red: 0.85, green: 0.14, blue: 0.45),
                        label: "Colors",
                        count: groups.colors.count,
                        clips: groups.colors,
                        onSelect: onSelect
                    )
                }

                if !groups.text.isEmpty {
                    CategoryGroup(
                        icon: .text,
                        iconColor: Color(red: 0.68, green: 0.17, blue: 0.72),
                        label: "Text",
                        count: groups.text.count,
                        clips: groups.text,
                        onSelect: onSelect
                    )
                }
            }
            .padding(.bottom, 2)

            // SNIPPETS Section
            CFSectionLabel("SNIPPETS")
                .padding(.horizontal, 8)
                .padding(.top, 8)

            SnippetsListView()
                .environment(\.managedObjectContext, CoreDataStack.shared.viewContext)
                .padding(.bottom, 4)
        }
        .padding(8)
    }
}

// MARK: - Hebrew/RTL History View
struct HebrewHistoryView: View {
    let clips: [SimpleClipItem]
    let onSelect: (SimpleClipItem) -> Void

    @Environment(\.cfTheme) var theme

    var body: some View {
        VStack(spacing: 2) {
            ForEach(Array(clips.prefix(10).enumerated()), id: \.element.id) { index, clip in
                ClipRow(
                    clip: clip,
                    index: index,
                    showNumber: true,
                    showMetadata: true,
                    rtl: true,
                    onSelect: { onSelect(clip) }
                )
            }
        }
        .padding(8)
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - Category Group
struct CategoryGroup: View {
    let icon: CFIcon.IconType
    let iconColor: Color
    let label: String
    let count: Int
    let clips: [SimpleClipItem]
    let onSelect: (SimpleClipItem) -> Void

    @State private var isExpanded = true
    @Environment(\.cfTheme) var theme

    var body: some View {
        VStack(spacing: 4) {
            // Header
            Button(action: { isExpanded.toggle() }) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(iconColor.opacity(0.22))
                            .frame(width: 22, height: 22)

                        CFIcon(type: icon, size: 13, stroke: 1.8)
                            .foregroundColor(iconColor)
                    }

                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.textStrong)

                    Spacer()

                    CFCountBadge(count: count)

                    CFIcon(
                        type: .chevronDown,
                        size: 12,
                        stroke: 1.8
                    )
                    .foregroundColor(theme.textMuted)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .padding(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)

            // Items
            if isExpanded {
                VStack(spacing: 2) {
                    ForEach(Array(clips.prefix(5).enumerated()), id: \.element.id) { index, clip in
                        ClipRow(
                            clip: clip,
                            index: index,
                            showNumber: false,
                            onSelect: { onSelect(clip) }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Clip Row
struct ClipRow: View {
    let clip: SimpleClipItem
    let index: Int
    let showNumber: Bool
    var showMetadata: Bool = false
    var rtl: Bool = false
    let onSelect: () -> Void

    @Environment(\.cfTheme) var theme

    private var displayText: String {
        String(clip.content.prefix(60)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var keyboardShortcut: String? {
        showNumber && index < 9 ? "\(index + 1)" : (index == 9 ? "0" : nil)
    }

    private var timeAgo: String {
        let interval = Date().timeIntervalSince(clip.createdAt)
        if interval < 60 {
            return "copied \(Int(interval))s ago"
        } else if interval < 3600 {
            return "copied \(Int(interval / 60))m ago"
        } else if interval < 86400 {
            return "copied \(Int(interval / 3600))h ago"
        } else {
            return "copied \(Int(interval / 86400))d ago"
        }
    }

    private var metadata: String {
        // For now, just show time. Could detect app later.
        if clip.type == "image" {
            return "PNG · 1840×1040 · 312 KB"
        } else if clip.content.hasPrefix("http") {
            return "\(timeAgo) • Safari"
        } else if clip.content.contains("=") && clip.content.contains("{") {
            return "3 lines • Xcode"
        } else {
            return timeAgo
        }
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                // Icon container - 26x26 with border-radius 5
                iconView

                // Text content
                VStack(alignment: rtl ? .trailing : .leading, spacing: showMetadata ? 2 : 0) {
                    Text(displayText)
                        .font(.system(size: 13))
                        .foregroundColor(theme.textStrong)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: rtl ? .trailing : .leading)

                    if showMetadata {
                        Text(metadata)
                            .font(.system(size: 11))
                            .foregroundColor(theme.textLabel)
                            .lineLimit(1)
                    }
                }

                // Keyboard shortcut
                if let shortcut = keyboardShortcut {
                    CFKBD(text: shortcut, dim: true)
                }
            }
            .padding(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
            .background(Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(PlainHoverButtonStyle())
        .padding(.horizontal, 6)
    }

    @ViewBuilder
    private var iconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(theme.fill1)
                .frame(width: 26, height: 26)

            // Render different icons based on content type
            if clip.content.hasPrefix("#") && clip.content.count >= 4 && clip.content.count <= 9 {
                // Hex color - show color swatch
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: clip.content) ?? theme.fill2)
                    .frame(width: 16, height: 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(theme.shadowStrong, lineWidth: 1)
                    )
            } else if clip.type == "image" {
                // Image - show thumbnail or image icon
                if let imageData = clip.imageData, let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 26, height: 26)
                        .clipped()
                        .cornerRadius(5)
                } else {
                    CFIcon(type: .image, size: 14, stroke: 1.6)
                        .foregroundColor(theme.textMid)
                }
            } else if clip.content.hasPrefix("http://") || clip.content.hasPrefix("https://") {
                // URL - show link icon
                CFIcon(type: .link, size: 14, stroke: 1.6)
                    .foregroundColor(theme.textMid)
            } else if clip.content.contains("{") || clip.content.contains("const ") || clip.content.contains("func ") {
                // Code - show bracket icon
                CFIcon(type: .bracket, size: 14, stroke: 1.6)
                    .foregroundColor(theme.textMid)
            } else {
                // Default - text icon
                CFIcon(type: .text, size: 14, stroke: 1.6)
                    .foregroundColor(theme.textMid)
            }
        }
    }
}

// MARK: - Snippets List View
struct SnippetsListView: View {
    @Environment(\.cfTheme) var theme
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Snippet.title, ascending: true)],
        predicate: NSPredicate(format: "isEnabled == YES"),
        animation: .default
    )
    private var snippets: FetchedResults<Snippet>

    var body: some View {
        VStack(spacing: 2) {
            ForEach(Array(snippets.prefix(2)), id: \.id) { snippet in
                MenuSnippetRow(snippet: snippet)
            }

            if snippets.isEmpty {
                Text("No snippets yet")
                    .font(.system(size: 13))
                    .foregroundColor(theme.textMuted)
                    .padding(.vertical, 12)
            }
        }
    }
}

// MARK: - Menu Snippet Row
struct MenuSnippetRow: View {
    let snippet: Snippet
    @Environment(\.cfTheme) var theme

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 10) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(theme.fill1)
                        .frame(width: 26, height: 26)

                    CFIcon(type: .bolt, size: 13, stroke: 1.8)
                        .foregroundColor(theme.textMid)
                }

                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    Text(snippet.title)
                        .font(.system(size: 13))
                        .foregroundColor(theme.textStrong)
                        .lineLimit(1)

                    if let apps = snippet.appRules, !apps.isEmpty {
                        let appNames = apps.compactMap { ($0 as? AppRule)?.appName }.prefix(2).joined(separator: ", ")
                        Text(".\(snippet.abbreviation) — \(appNames)")
                            .font(.system(size: 11))
                            .foregroundColor(theme.textLabel)
                            .lineLimit(1)
                    } else {
                        Text(".\(snippet.abbreviation) — anywhere")
                            .font(.system(size: 11))
                            .foregroundColor(theme.textLabel)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Abbreviation on right
                Text(".\(snippet.abbreviation)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(theme.textSubtle)
            }
            .padding(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
            .background(Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(PlainHoverButtonStyle())
        .padding(.horizontal, 6)
    }
}

// MARK: - Color Hex Extension
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    MenuBarPopover(
        clipboardMonitor: ClipboardMonitor(),
        isPresented: .constant(true)
    )
    .cfAutoTheme()
    .frame(height: 600)
}
