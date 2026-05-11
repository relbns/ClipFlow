import SwiftUI

/// Modern SwiftUI MenuBar Popover - replaces NSMenu
struct MenuBarPopover: View {
    let clipboardMonitor: ClipboardMonitor
    @Binding var isPresented: Bool

    @AppStorage("viewMode") private var viewMode = "organized"
    @State private var searchText = ""

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
                        onSelect: selectClip
                    )
                }
            }
            .frame(maxHeight: 500)

            Divider()

            // Footer
            footerView
        }
        .frame(width: 340)
        .background(theme.popoverBg)
    }

    // MARK: - Header
    private var headerView: some View {
        VStack(spacing: 0) {
            // Search - padding 8px 8px 6px
            VStack(spacing: 0) {
                CFInput(
                    text: $searchText,
                    placeholder: "Search clipboard...",
                    prefix: nil,
                    suffix: AnyView(
                        HStack(spacing: 6) {
                            CFKBD(text: "⌘F", dim: true)
                            CFIcon(type: .search, size: 13, stroke: 1.8)
                                .foregroundColor(theme.textSubtle)
                        }
                    )
                )
            }
            .padding(EdgeInsets(top: 8, leading: 8, bottom: 6, trailing: 8))

            // Mode Switcher (if not Hebrew)
            if viewMode != "hebrew" {
                HStack(spacing: 8) {
                    modeButton("Simple", icon: .text, isActive: viewMode == "simple") {
                        viewMode = "simple"
                    }

                    modeButton("Organized", icon: .folder, isActive: viewMode == "organized") {
                        viewMode = "organized"
                    }

                    Spacer()

                    Button(action: { viewMode = "hebrew" }) {
                        CFIcon(type: .hebrew, size: 14, stroke: 1.8)
                            .foregroundColor(theme.textMuted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(EdgeInsets(top: 0, leading: 12, bottom: 12, trailing: 12))
            }
        }
    }

    private func modeButton(_ label: String, icon: CFIcon.IconType, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                CFIcon(type: icon, size: 12, stroke: 1.8)
                    .foregroundColor(isActive ? theme.accent : theme.textMuted)

                Text(label)
                    .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? theme.textStrong : theme.textMuted)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isActive ? theme.accent.opacity(0.15) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer
    private var footerView: some View {
        VStack(spacing: 0) {
            CFFooterRowBtn(icon: .sparkles, label: "Snippet Editor…", kbd: "⌘E") {
                openSnippetEditor()
            }

            CFFooterRowBtn(icon: .gear, label: "Preferences…", kbd: "⌘,") {
                openPreferences()
            }

            Divider()

            CFFooterRowBtn(icon: .trash, label: "Clear history") {
                clearClipboardHistory()
            }

            CFFooterRowBtn(icon: .power, label: "Quit ClipFlow", kbd: "⌘Q", danger: true) {
                NSApp.terminate(nil)
            }
        }
        .background(theme.fill1)
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

    private func clearClipboardHistory() {
        clipboardMonitor.clearHistory()
        isPresented = false
    }
}

// MARK: - Simple History View
struct SimpleHistoryView: View {
    let clips: [SimpleClipItem]
    let onSelect: (SimpleClipItem) -> Void

    @Environment(\.cfTheme) var theme

    var body: some View {
        VStack(spacing: 2) {
            if clips.isEmpty {
                emptyState
            } else {
                ForEach(Array(clips.prefix(10).enumerated()), id: \.element.id) { index, clip in
                    ClipRow(
                        clip: clip,
                        index: index,
                        showNumber: true,
                        onSelect: { onSelect(clip) }
                    )
                }
            }
        }
        .padding(8)
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
        VStack(spacing: 12) {
            let groups = groupedClips

            CategoryGroup(
                icon: .clock,
                iconColor: Color(red: 0.78, green: 0.14, blue: 0.70),
                label: "Recent",
                count: groups.recent.count,
                clips: groups.recent,
                onSelect: onSelect
            )

            // Snippets section
            CategoryGroup(
                icon: .sparkles,
                iconColor: Color(red: 0.47, green: 0.44, blue: 1.0),
                label: "Snippets",
                count: 0,  // TODO: Fetch from Core Data
                clips: [],
                onSelect: { _ in }
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
    var rtl: Bool = false
    let onSelect: () -> Void

    @Environment(\.cfTheme) var theme

    private var displayText: String {
        String(clip.content.prefix(60)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var keyboardShortcut: String? {
        showNumber && index < 9 ? "\(index + 1)" : (index == 9 ? "0" : nil)
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                // Icon container - 26x26 with border-radius 5
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(theme.fill1)
                        .frame(width: 26, height: 26)

                    CFIcon(
                        type: iconForType(clip.type),
                        size: 14,
                        stroke: 1.6
                    )
                    .foregroundColor(theme.textMid)
                }

                // Text
                Text(displayText)
                    .font(.system(size: 13))
                    .foregroundColor(theme.textStrong)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: rtl ? .trailing : .leading)

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

    private func iconForType(_ type: String) -> CFIcon.IconType {
        switch type {
        case "image": return .image
        case "url": return .link
        default: return .text
        }
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
