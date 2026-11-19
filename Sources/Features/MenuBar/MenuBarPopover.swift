import SwiftUI

/// The history popover, built from `design_handoff_clipflow/design/components/menubar.jsx`.
struct MenuBarPopover: View {
    @ObservedObject var clipboardMonitor: ClipboardMonitor
    @Binding var isPresented: Bool
    var onSizeChange: (CGSize) -> Void = { _ in }
    @ObservedObject private var navigation = PopoverNavigation.shared
    @AppStorage("viewMode") private var viewMode = "organized"
    @State private var contentHeight: CGFloat = 0
    @Environment(\.cfTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            searchField
            if navigation.drilledCategory != nil, navigation.searchText.isEmpty {
                drillHeader
            }
            list
            PopoverDivider()
            footer
        }
        .frame(width: 340)
        .background(theme.popoverBg)
        .fixedSize(horizontal: false, vertical: true)
        .background(GeometryReader { proxy in
            Color.clear.preference(key: PopoverSizeKey.self, value: proxy.size)
        })
        .onPreferenceChange(PopoverSizeKey.self) { size in
            if size != .zero { onSizeChange(size) }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .environment(\.selectedPopoverItemID, navigation.selectedID)
    }

    // MARK: - Search

    private var searchField: some View {
        CFInput(
            text: $navigation.searchText,
            placeholder: L("search_clipboard"),
            prefix: AnyView(CFIcon(type: .search, size: 13, stroke: 1.8).foregroundColor(theme.textSubtle)),
            suffix: AnyView(CFKBDChip("⌘F", dim: true))
        )
        .padding(EdgeInsets(top: 8, leading: 8, bottom: 6, trailing: 8))
    }

    private var drillHeader: some View {
        Button(action: navigation.goBack) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.backward").font(.system(size: 11, weight: .semibold))
                Text(L("section_categories")).font(.system(size: 12))
                Spacer()
            }
            .foregroundColor(theme.textMuted)
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("back"))
    }

    // MARK: - List

    private var list: some View {
        ScrollViewReader { scroller in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    let sections = navigation.sections
                    ForEach(sections) { section in
                        PopoverSectionHeader(title: section.title, trailing: section.trailing)
                        ForEach(section.items) { item in
                            row(for: item).id(item.id)
                        }
                        Spacer().frame(height: 4)
                    }
                    if sections.allSatisfy({ $0.items.isEmpty }) {
                        emptyState
                    }
                }
                .background(GeometryReader { proxy in
                    Color.clear.preference(key: PopoverContentHeightKey.self, value: proxy.size.height)
                })
            }
            .onPreferenceChange(PopoverContentHeightKey.self) { contentHeight = $0 }
            .frame(height: min(max(contentHeight, 60), navigation.maxListHeight))
            .onChange(of: navigation.selectedID) { _, id in
                if let id { scroller.scrollTo(id) }
            }
        }
    }

    @ViewBuilder
    private func row(for item: PopoverItem) -> some View {
        switch item {
        case .clip(let clip, let number):
            PopoverClipRow(clip: clip, trailing: number.map { $0 == 10 ? "0" : "\($0)" }, itemID: item.id)
                .onTapGesture { navigation.activate(item) }
                .contextMenu { clipMenu(clip) }
        case .pinned(let clip, let slot):
            PopoverClipRow(clip: clip, trailing: "⌘\(slot)", pinned: true, itemID: item.id)
                .onTapGesture { navigation.activate(item) }
                .contextMenu { clipMenu(clip) }
        case .category(let category, let count):
            PopoverCategoryRow(category: category, count: count, itemID: item.id)
                .onTapGesture { navigation.activate(item) }
        case .snippet(let snippet):
            PopoverSnippetRow(snippet: snippet, itemID: item.id)
                .onTapGesture { navigation.activate(item) }
        }
    }

    @ViewBuilder
    private func clipMenu(_ clip: SimpleClipItem) -> some View {
        Button(clip.isPinned ? L("unpin") : L("pin")) { navigation.togglePin(clip) }
        Button(L("delete_clip"), role: .destructive) { navigation.delete(clip) }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            CFIcon(type: .clock, size: 28, stroke: 1.4).foregroundColor(theme.textFaint)
            Text(navigation.searchText.isEmpty ? L("no_history") : L("no_results"))
                .font(.system(size: 13))
                .foregroundColor(theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            CFFooterRowBtn(icon: .sparkles, label: L("menu_snippet_editor"), kbd: "⌘E") {
                post("OpenSnippetEditor")
            }
            CFFooterRowBtn(icon: .gear, label: L("menu_preferences"), kbd: "⌘,") {
                post("OpenPreferences")
            }
            CFFooterRowBtn(icon: .info, label: L("menu_about")) {
                post("OpenAbout")
            }
            PopoverDivider()
            CFFooterRowBtn(icon: .trash, label: L("menu_clear_history")) {
                clipboardMonitor.clearHistory()
                isPresented = false
            }
            CFFooterRowBtn(icon: .power, label: L("menu_quit"), kbd: "⌘Q") {
                NSApp.terminate(nil)
            }
            CFSegmentedControl(
                selection: Binding(
                    get: { viewMode == "simple" ? 0 : 1 },
                    set: { viewMode = $0 == 0 ? "simple" : "organized"; navigation.drilledCategory = nil }
                ),
                options: [L("mode_simple"), L("mode_organized")]
            )
            .padding(EdgeInsets(top: 6, leading: 10, bottom: 10, trailing: 10))
        }
    }

    private func post(_ name: String) {
        isPresented = false
        NotificationCenter.default.post(name: NSNotification.Name(name), object: nil)
    }
}

// MARK: - Rows

private struct PopoverSectionHeader: View {
    let title: String
    let trailing: String?
    @Environment(\.cfTheme) private var theme

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.06 * 10.5)
                .textCase(.uppercase)
                .foregroundColor(theme.textLabel)
            Spacer()
            if let trailing {
                Text(trailing).font(.system(size: 10.5)).foregroundColor(theme.textSubtle)
            }
        }
        .padding(EdgeInsets(top: 6, leading: 14, bottom: 4, trailing: 14))
    }
}

/// The design's ClipRow: 26pt tile, title and subtitle, trailing kbd chip; tinted when selected.
private struct PopoverClipRow: View {
    let clip: SimpleClipItem
    let trailing: String?
    var pinned = false
    let itemID: String
    @Environment(\.selectedPopoverItemID) private var selectedID
    @Environment(\.cfTheme) private var theme

    private var isSelected: Bool { selectedID == itemID }

    var body: some View {
        HStack(spacing: 10) {
            ClipTile(clip: clip, pinned: pinned)
            VStack(alignment: .leading, spacing: 1) {
                Text(clip.title)
                    .font(clip.looksLikeCode ? .system(size: 12, design: .monospaced) : .system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundColor(theme.textStrong)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(clip.subtitle())
                    .font(.system(size: 11))
                    .foregroundColor(theme.textLabel)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let trailing {
                CFKBDChip(trailing, dim: !isSelected)
                    .environment(\.layoutDirection, .leftToRight)
            }
        }
        .padding(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
        .background(RoundedRectangle(cornerRadius: 6).fill(isSelected ? BrandPalette.selectedRow : .clear))
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

private struct ClipTile: View {
    let clip: SimpleClipItem
    var pinned = false
    @Environment(\.cfTheme) private var theme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5).fill(theme.fill1)
            content.foregroundColor(theme.textMid)
        }
        .frame(width: 26, height: 26)
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    @ViewBuilder
    private var content: some View {
        if pinned {
            CFIcon(type: .pin, size: 13, stroke: 1.6)
        } else if clip.kind == .image, let data = clip.imageData, let image = NSImage(data: data) {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fill).frame(width: 26, height: 26)
        } else if clip.kind == .color {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: clip.content.trimmingCharacters(in: .whitespacesAndNewlines)) ?? theme.fill2)
                .frame(width: 16, height: 16)
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(theme.shadowStrong, lineWidth: 1))
        } else if clip.kind == .url {
            CFIcon(type: .link, size: 14, stroke: 1.6)
        } else if clip.kind == .file {
            CFIcon(type: .folder, size: 14, stroke: 1.6)
        } else if clip.looksLikeCode {
            CFIcon(type: .bracket, size: 14, stroke: 1.6)
        } else {
            CFIcon(type: .text, size: 14, stroke: 1.6)
        }
    }
}

private struct PopoverCategoryRow: View {
    let category: PopoverCategory
    let count: Int
    let itemID: String
    @Environment(\.selectedPopoverItemID) private var selectedID
    @Environment(\.cfTheme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(category.accent.mixed(22))
                CFIcon(type: category.icon, size: 13, stroke: 1.8).foregroundColor(category.accent)
            }
            .frame(width: 22, height: 22)
            Text(L(category.titleKey))
                .font(.system(size: 13))
                .foregroundColor(theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(count)")
                .font(.system(size: 11))
                .foregroundColor(theme.textSubtle)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Capsule().fill(theme.fill1))
            Image(systemName: "chevron.forward")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(theme.textFaint)
        }
        .padding(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
        .background(RoundedRectangle(cornerRadius: 6).fill(selectedID == itemID ? BrandPalette.selectedRow : .clear))
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

private struct PopoverSnippetRow: View {
    let snippet: SnippetSummary
    let itemID: String
    @Environment(\.selectedPopoverItemID) private var selectedID
    @Environment(\.cfTheme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 5).fill(theme.fill1)
                CFIcon(type: .bolt, size: 13, stroke: 1.8).foregroundColor(theme.textMid)
            }
            .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(snippet.title).font(.system(size: 13)).foregroundColor(theme.textStrong).lineLimit(1)
                Text("\(snippet.abbreviation) · \(snippet.apps.isEmpty ? L("everywhere") : snippet.apps.prefix(2).joined(separator: ", "))")
                    .font(.system(size: 11))
                    .foregroundColor(theme.textLabel)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(snippet.abbreviation)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(theme.textSubtle)
                .environment(\.layoutDirection, .leftToRight)
        }
        .padding(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
        .background(RoundedRectangle(cornerRadius: 6).fill(selectedID == itemID ? BrandPalette.selectedRow : .clear))
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

private struct PopoverDivider: View {
    @Environment(\.cfTheme) private var theme

    var body: some View {
        Rectangle().fill(theme.stroke).frame(height: 1).padding(.vertical, 4)
    }
}

private struct PopoverContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

extension SimpleClipItem {
    /// Shown in monospace with a bracket glyph, like the design's code row.
    var looksLikeCode: Bool {
        guard kind == .text || kind == .rtf else { return false }
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let starts = ["const ", "let ", "var ", "func ", "function ", "import ", "def ", "class ", "return ", "#include", "SELECT "]
        return starts.contains(where: text.hasPrefix) || text.contains("=>") || (text.contains("{") && text.contains("}")) || text.hasSuffix(";")
    }
}

extension Color {
    /// `#RGB`, `#RRGGBB` or `#AARRGGBB` text from a copied color.
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&value) else { return nil }
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (value >> 8) * 17, (value >> 4 & 0xF) * 17, (value & 0xF) * 17)
        case 6: (a, r, g, b) = (255, value >> 16, value >> 8 & 0xFF, value & 0xFF)
        case 8: (a, r, g, b) = (value >> 24, value >> 16 & 0xFF, value >> 8 & 0xFF, value & 0xFF)
        default: return nil
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
