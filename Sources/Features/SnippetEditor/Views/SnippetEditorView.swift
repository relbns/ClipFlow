import CoreData
import SwiftUI

/// The Snippet Editor, built from `design_handoff_clipflow/design/components/editor.jsx`:
/// a 230pt sidebar, the editor, and a 280pt inspector under a 38pt title bar.
struct SnippetEditorView: View {
    @Environment(\.managedObjectContext) private var context
    var onTitleChange: (String) -> Void = { _ in }

    var body: some View {
        SnippetEditorContent(context: context, onTitleChange: onTitleChange)
    }
}

private struct SnippetEditorContent: View {
    @StateObject var model: SnippetEditorModel
    let onTitleChange: (String) -> Void
    @Environment(\.cfTheme) private var theme

    init(context: NSManagedObjectContext, onTitleChange: @escaping (String) -> Void) {
        _model = StateObject(wrappedValue: SnippetEditorModel(context: context))
        self.onTitleChange = onTitleChange
    }

    private var title: String {
        guard let snippet = model.selected else { return L("snippet_editor") }
        return "\(L("snippet_editor")) — \(snippet.title)"
    }

    var body: some View {
        VStack(spacing: 0) {
            EditorTitleBar(title: title, model: model)
            HStack(spacing: 0) {
                EditorSidebar(model: model)
                    .frame(width: 230)
                Group {
                    if let snippet = model.selected {
                        EditorPane(snippet: snippet, model: model)
                            .id(snippet.objectID)
                    } else {
                        EditorEmptyState(model: model)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.surface)
                if let snippet = model.selected {
                    EditorInspector(snippet: snippet, model: model)
                        .frame(width: 280)
                        .id(snippet.objectID)
                }
            }
        }
        .frame(minWidth: 1020, idealWidth: 1080, minHeight: 520, idealHeight: 700)
        .background(theme.surface)
        .ignoresSafeArea(.container, edges: .top)
        .onAppear {
            model.selectFirstIfNeeded()
            onTitleChange(title)
        }
        .onChange(of: title) { _, newTitle in onTitleChange(newTitle) }
        .alert(L("delete_snippet_title"), isPresented: Binding(get: { model.confirmingDelete != nil }, set: { if !$0 { model.confirmingDelete = nil } })) {
            Button(L("delete"), role: .destructive) {
                if let snippet = model.confirmingDelete { model.delete(snippet) }
                model.confirmingDelete = nil
            }
            Button(L("cancel"), role: .cancel) { model.confirmingDelete = nil }
        } message: {
            Text(L("delete_snippet_message", model.confirmingDelete?.title ?? ""))
        }
        .alert(L("delete_group_title"), isPresented: Binding(get: { model.confirmingGroupDelete != nil }, set: { if !$0 { model.confirmingGroupDelete = nil } })) {
            Button(L("delete"), role: .destructive) {
                if let group = model.confirmingGroupDelete { model.delete(group) }
                model.confirmingGroupDelete = nil
            }
            Button(L("cancel"), role: .cancel) { model.confirmingGroupDelete = nil }
        } message: {
            Text(L("delete_group_message", model.confirmingGroupDelete?.name ?? ""))
        }
    }
}

// MARK: - Title bar

/// Drawn in the window's transparent title bar; the traffic lights sit in the leading 78pt.
private struct EditorTitleBar: View {
    let title: String
    @ObservedObject var model: SnippetEditorModel
    @Environment(\.cfTheme) private var theme
    @Environment(\.layoutDirection) private var layoutDirection

    /// The window buttons keep the side they had at launch; after an in-app language switch they sit at our trailing edge.
    private var trafficLightsOnTrailingEdge: Bool {
        (layoutDirection == .rightToLeft) != (NSApp.userInterfaceLayoutDirection == .rightToLeft)
    }

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.textMid)
                .lineLimit(1)
                .padding(.horizontal, 220)
            HStack(spacing: 6) {
                Spacer()
                CFToolbarBtn(icon: AnyView(CFIcon(type: .plus, size: 12, stroke: 1.8)), label: L("new")) { model.newSnippet() }
                    .keyboardShortcut("n", modifiers: .command)
                CFToolbarBtn(label: L("duplicate")) {
                    if let snippet = model.selected { model.duplicate(snippet) }
                }
                .disabled(model.selected == nil)
                .keyboardShortcut("d", modifiers: .command)
            }
            .padding(.leading, 12)
            .padding(.trailing, trafficLightsOnTrailingEdge ? 78 : 12)
        }
        .frame(height: 38)
        .background(theme.titlebarBg)
        .overlay(Rectangle().fill(theme.strokeSoft).frame(height: 1), alignment: .bottom)
    }
}

// MARK: - Sidebar

private struct EditorSidebar: View {
    @ObservedObject var model: SnippetEditorModel
    @ObservedObject private var sharedGroups = SharedGroups.shared
    @Environment(\.cfTheme) private var theme

    private func share(_ group: SnippetGroup) {
        guard let folder = SharedGroupsSettingsRow.chooseFolder(prompt: L("shared_share_prompt")) else { return }
        do {
            try sharedGroups.share(group.id, in: folder)
        } catch {
            let alert = NSAlert()
            alert.messageText = L("shared_failed")
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterField
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    SidebarCaption(title: L("editor_library"))
                    libraryRow(.favorites, icon: .star, title: L("editor_favorites"))
                    libraryRow(.recent, icon: .clock, title: L("editor_recent"))

                    if let library = model.library {
                        SidebarCaption(title: L(library == .favorites ? "editor_favorites" : "editor_recent"))
                        ForEach(model.snippets(in: library), id: \.objectID) { snippet in
                            snippetRow(snippet, depth: 0)
                        }
                    } else {
                        HStack {
                            SidebarCaption(title: L("editor_groups"))
                            Button { model.newGroup() } label: {
                                CFIcon(type: .plus, size: 12, stroke: 1.8).foregroundColor(theme.textSubtle)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(L("editor_new_group"))
                            .padding(.trailing, 14)
                            .padding(.top, 8)
                        }
                        ForEach(model.groups, id: \.objectID) { group in
                            groupRow(group)
                            if !model.collapsedGroups.contains(group.objectID) || !model.filterText.isEmpty {
                                ForEach(model.snippets(in: group), id: \.objectID) { snippet in
                                    snippetRow(snippet, depth: 1)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            footer
        }
        .background(theme.surfaceAlt)
        .overlay(Rectangle().fill(theme.strokeSoft).frame(width: 1), alignment: .trailing)
    }

    private var filterField: some View {
        HStack(spacing: 8) {
            CFIcon(type: .search, size: 12, stroke: 1.8).foregroundColor(theme.textSubtle)
            TextField(L("editor_search"), text: $model.filterText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
        }
        .padding(.horizontal, 8)
        .frame(height: 26)
        .background(RoundedRectangle(cornerRadius: 6).fill(theme.inputBg))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(theme.stroke, lineWidth: 1))
        .padding(EdgeInsets(top: 10, leading: 8, bottom: 6, trailing: 8))
    }

    private func libraryRow(_ library: SnippetEditorModel.Library, icon: CFIcon.IconType, title: String) -> some View {
        Button { model.library = model.library == library ? nil : library } label: {
            SidebarRow(
                icon: AnyView(CFIcon(type: icon, size: 13, stroke: 1.6)),
                label: title,
                count: model.count(in: library),
                active: model.library == library
            )
        }
        .buttonStyle(.plain)
    }

    private func groupRow(_ group: SnippetGroup) -> some View {
        let collapsed = model.collapsedGroups.contains(group.objectID) && model.filterText.isEmpty
        return Group {
            if model.renamingGroupID == group.objectID {
                GroupNameField(group: group, model: model)
            } else {
                Button { model.toggleCollapsed(group) } label: {
                    SidebarRow(
                        icon: AnyView(Image(systemName: collapsed ? "chevron.forward" : "chevron.down").font(.system(size: 10, weight: .semibold))),
                        label: sharedGroups.isShared(group.id) ? "\(group.name) · \(L("group_shared"))" : group.name,
                        count: nil,
                        active: false,
                        dimmed: !group.isEnabled
                    )
                }
                .buttonStyle(.plain)
                .accessibilityValue(L(collapsed ? "a11y_collapsed" : "a11y_expanded"))
                .contextMenu {
                    Button(L("editor_rename_group")) { model.renamingGroupID = group.objectID }
                    Button(group.isEnabled ? L("editor_disable_group") : L("editor_enable_group")) { model.toggleEnabled(group) }
                    if let folder = sharedGroups.folder(of: group.id) {
                        Button(L("editor_stop_sharing")) { sharedGroups.stopSharing(folder: folder) }
                    } else {
                        Button(L("editor_share_group")) { share(group) }
                    }
                    Divider()
                    Button(L("editor_delete_group"), role: .destructive) { model.confirmingGroupDelete = group }
                }
            }
        }
    }

    private func snippetRow(_ snippet: Snippet, depth: Int) -> some View {
        Button { model.select(snippet) } label: {
            SidebarRow(
                icon: AnyView(CFIcon(type: snippet.isFavorite ? .star : .bolt, size: 12, stroke: 1.6)),
                label: snippet.title.isEmpty ? snippet.abbreviation : snippet.title,
                count: nil,
                active: model.selectedID == snippet.objectID,
                depth: depth,
                dimmed: !snippet.isEnabled || snippet.group?.isEnabled == false
            )
        }
        .buttonStyle(.plain)
        .accessibilityValue(snippet.isFavorite ? L("editor_favorites") : "")
        .contextMenu {
            Button(snippet.isFavorite ? L("editor_unfavorite") : L("editor_favorite")) { model.toggleFavorite(snippet) }
            Button(L("duplicate")) { model.duplicate(snippet) }
            Divider()
            Button(L("delete"), role: .destructive) { model.confirmingDelete = snippet }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            CFIcon(type: .bolt, size: 12, stroke: 1.6)
            Text(L("editor_snippet_count", count: model.totalCount))
        }
        .font(.system(size: 11))
        .foregroundColor(theme.textSubtle)
        .padding(.horizontal, 12)
        .frame(height: 30)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().fill(theme.strokeSoft).frame(height: 1), alignment: .top)
    }
}

private struct SidebarCaption: View {
    let title: String
    @Environment(\.cfTheme) private var theme

    var body: some View {
        Text(title)
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(0.06 * 10.5)
            .textCase(.uppercase)
            .foregroundColor(theme.textLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(EdgeInsets(top: 14, leading: 14, bottom: 4, trailing: 14))
    }
}

/// The design's SidebarItem: icon, label, optional count; tinted when active, indented by depth.
private struct SidebarRow: View {
    let icon: AnyView
    let label: String
    let count: Int?
    let active: Bool
    var depth = 0
    var dimmed = false
    @Environment(\.cfTheme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            icon.foregroundColor(active ? BrandPalette.sidebarActiveIcon : theme.textMuted).frame(width: 14)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(active ? theme.textStrong : (dimmed ? theme.textFaint : theme.text))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let count {
                Text("\(count)").font(.system(size: 11)).foregroundColor(theme.textFaint)
            }
        }
        .padding(.vertical, 4)
        .padding(.leading, 10 + CGFloat(depth) * 14)
        .padding(.trailing, 10)
        .background(RoundedRectangle(cornerRadius: 6).fill(active ? Color.hex(0x7B71FF, alpha: 0.22) : .clear))
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

private struct GroupNameField: View {
    let group: SnippetGroup
    @ObservedObject var model: SnippetEditorModel
    @State private var name: String
    @State private var cancelled = false
    @FocusState private var focused: Bool
    @Environment(\.cfTheme) private var theme

    init(group: SnippetGroup, model: SnippetEditorModel) {
        self.group = group
        self.model = model
        _name = State(initialValue: group.name)
    }

    var body: some View {
        TextField(L("editor_group_name"), text: $name)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .focused($focused)
            .onSubmit { model.rename(group, to: name) }
            .onExitCommand {
                cancelled = true
                model.renamingGroupID = nil
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: 5).fill(theme.inputBg))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(theme.accent, lineWidth: 1))
            .padding(.horizontal, 12)
            .onAppear { focused = true }
            .onChange(of: focused) { _, isFocused in
                if !isFocused, !cancelled { model.rename(group, to: name) }
            }
    }
}

private struct EditorEmptyState: View {
    @ObservedObject var model: SnippetEditorModel
    @Environment(\.cfTheme) private var theme

    var body: some View {
        VStack(spacing: 12) {
            CFIcon(type: .bolt, size: 28, stroke: 1.4).foregroundColor(theme.textFaint)
            Text(L("editor_no_snippets")).font(.system(size: 13)).foregroundColor(theme.textMuted)
            CFToolbarBtn(icon: AnyView(CFIcon(type: .plus, size: 12, stroke: 1.8)), label: L("new"), primary: true) { model.newSnippet() }
        }
    }
}
