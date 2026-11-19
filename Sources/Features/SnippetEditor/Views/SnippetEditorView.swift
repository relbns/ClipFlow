import SwiftUI
import CoreData

struct SnippetEditorView: View {
    var body: some View {
        SnippetEditorContentView()
    }
}

private struct SnippetEditorContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SnippetGroup.sortOrder, ascending: true)],
        animation: .default)
    private var groups: FetchedResults<SnippetGroup>

    @State private var selectedGroup: SnippetGroup?
    @State private var selectedSnippet: Snippet?
    @State private var searchText = ""

    private var filteredGroups: [SnippetGroup] {
        if searchText.isEmpty {
            return Array(groups)
        }

        return groups.compactMap { group in
            let matchingSnippets = group.sortedSnippets.filter { snippet in
                snippet.title.localizedCaseInsensitiveContains(searchText) ||
                snippet.abbreviation.localizedCaseInsensitiveContains(searchText) ||
                snippet.content.localizedCaseInsensitiveContains(searchText)
            }

            if !matchingSnippets.isEmpty {
                return group
            }
            return nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            EditorToolbar(
                selectedSnippet: selectedSnippet,
                onNew: createSnippet,
                onDuplicate: duplicateSelectedSnippet,
                onDelete: deleteSelectedSnippet
            )

            Divider()

            // Main Content
            ThreePanelLayout(
                leftPanel: {
                    GroupsPanel(
                        groups: groups,
                        selectedGroup: $selectedGroup,
                        onCreateGroup: createGroup
                    )
                },
                middlePanel: {
                    SnippetsPanel(
                        group: selectedGroup,
                        filteredGroups: filteredGroups,
                        searchText: $searchText,
                        selectedSnippet: $selectedSnippet,
                        filteredSnippets: filteredSnippets,
                        onCreateSnippet: createSnippet
                    )
                },
                rightPanel: {
                    EditorPanel(selectedSnippet: selectedSnippet)
                }
            )

            Divider()

            // Status Bar
            EditorStatusBar(selectedSnippet: selectedSnippet)
        }
        .frame(minWidth: 1080, minHeight: 700)
    }

    private func createGroup() {
        withAnimation {
            let newGroup = SnippetGroup(context: viewContext)
            newGroup.id = UUID()
            newGroup.name = L("editor_new_group")
            newGroup.isEnabled = true
            newGroup.sortOrder = Int32(groups.count)
            newGroup.createdAt = Date()

            do {
                try viewContext.save()
            } catch {
                Log.ui.error("Failed to create group: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func createSnippet() {

        guard let group = selectedGroup ?? groups.first else {

            // Create default group if none exists
            let defaultGroup = SnippetGroup(context: viewContext)
            defaultGroup.id = UUID()
            defaultGroup.name = L("editor_default_group")
            defaultGroup.isEnabled = true
            defaultGroup.sortOrder = 0
            defaultGroup.createdAt = Date()

            do {
                try viewContext.save()
            } catch {
                Log.ui.error("Failed to create default group: \(error.localizedDescription, privacy: .public)")
                return
            }

            // Try again with the new group
            createSnippet()
            return
        }


        withAnimation {
            let newSnippet = Snippet(context: viewContext)
            newSnippet.id = UUID()
            newSnippet.title = L("editor_new_snippet")
            newSnippet.abbreviation = ".new"
            newSnippet.content = ""
            newSnippet.isEnabled = true
            newSnippet.createdAt = Date()
            newSnippet.updatedAt = Date()
            newSnippet.expandTrigger = UserDefaults.standard.string(forKey: "expandAfter") ?? ExpandTrigger.delimiter.rawValue
            newSnippet.caseSensitive = false
            newSnippet.playSound = false
            newSnippet.useCount = 0
            newSnippet.group = group

            do {
                try viewContext.save()
                selectedSnippet = newSnippet
            } catch {
                Log.ui.error("Failed to create snippet: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func filteredSnippets(for group: SnippetGroup) -> [Snippet] {
        let snippets = group.sortedSnippets

        if searchText.isEmpty {
            return snippets
        }

        return snippets.filter { snippet in
            snippet.title.localizedCaseInsensitiveContains(searchText) ||
            snippet.abbreviation.localizedCaseInsensitiveContains(searchText) ||
            snippet.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func duplicateSelectedSnippet() {
        guard let original = selectedSnippet else { return }

        withAnimation {
            let duplicate = Snippet(context: viewContext)
            duplicate.id = UUID()
            duplicate.title = original.title + " (Copy)"
            duplicate.abbreviation = original.abbreviation + "2"
            duplicate.content = original.content
            duplicate.isEnabled = original.isEnabled
            duplicate.createdAt = Date()
            duplicate.updatedAt = Date()
            duplicate.expandTrigger = original.expandTrigger
            duplicate.caseSensitive = original.caseSensitive
            duplicate.playSound = original.playSound
            duplicate.useCount = 0
            duplicate.group = original.group

            do {
                try viewContext.save()
                selectedSnippet = duplicate
            } catch {
                Log.ui.error("Failed to duplicate snippet: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func deleteSelectedSnippet() {
        guard let snippet = selectedSnippet else { return }

        withAnimation {
            viewContext.delete(snippet)
            selectedSnippet = nil

            do {
                try viewContext.save()
            } catch {
                Log.ui.error("Failed to delete snippet: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

private struct SnippetRow: View {
    @Environment(\.cfTheme) private var theme
    @ObservedObject var snippet: Snippet

    var body: some View {
        HStack {
            Image(systemName: snippet.isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(snippet.isEnabled ? theme.success : theme.textMuted)

            VStack(alignment: .leading, spacing: 2) {
                Text(snippet.title)
                    .font(.body)

                Text(snippet.abbreviation)
                    .font(.caption)
                    .foregroundColor(theme.textMuted)
            }

            Spacer()

            if snippet.useCount > 0 {
                Text("\(snippet.useCount)")
                    .font(.caption)
                    .foregroundColor(theme.textMuted)
            }
        }
    }
}

private struct SnippetDetailView: View {
    @Environment(\.cfTheme) private var theme
    @ObservedObject var snippet: Snippet
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Snippet.abbreviation, ascending: true)],
        animation: .default)
    private var allSnippets: FetchedResults<Snippet>

    private var abbreviationValidation: (isValid: Bool, message: String?) {
        let abbr = snippet.abbreviation.trimmingCharacters(in: .whitespaces)

        if abbr.isEmpty {
            return (false, L("abbr_error_empty"))
        }

        let validPrefixes = [".", ";", "/"]
        let hasValidPrefix = validPrefixes.contains(where: { abbr.hasPrefix($0) })
        if !hasValidPrefix {
            return (false, L("abbr_error_prefix"))
        }

        if abbr.contains(" ") {
            return (false, L("abbr_error_spaces"))
        }

        // Allow alphanumerics (includes Hebrew), special chars, and Hebrew letters explicitly
        var allowedCharacters = CharacterSet.alphanumerics
        allowedCharacters.formUnion(CharacterSet(charactersIn: ".;/_-"))
        allowedCharacters.formUnion(CharacterSet(charactersIn: "א...ת"))  // Hebrew letters range

        if abbr.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
            return (false, L("abbr_error_characters"))
        }

        let duplicate = allSnippets.first { otherSnippet in
            otherSnippet.id != snippet.id && otherSnippet.abbreviation == abbr
        }
        if duplicate != nil {
            return (false, L("abbr_error_duplicate"))
        }

        return (true, nil)
    }

    var body: some View {
        Form {
            Section(L("editor_section_basic")) {
                TextField(L("editor_title"), text: $snippet.title)

                VStack(alignment: .leading, spacing: 4) {
                    TextField(L("editor_abbreviation"), text: $snippet.abbreviation)
                        .help(L("editor_abbreviation_help"))

                    if let message = abbreviationValidation.message {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(theme.warning)
                                .font(.caption)
                            Text(message)
                                .font(.caption)
                                .foregroundColor(theme.warning)
                        }
                    } else if !snippet.abbreviation.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(theme.success)
                                .font(.caption)
                            Text(L("abbr_valid"))
                                .font(.caption)
                                .foregroundColor(theme.success)
                        }
                    }
                }

                Toggle(L("editor_enabled"), isOn: $snippet.isEnabled)
            }

            Section(L("editor_section_content")) {
                TextEditor(text: $snippet.content)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200)
                    .environment(\.layoutDirection, snippet.content.isRTL ? .rightToLeft : .leftToRight)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Button(action: { insertVariable("{date}") }) {
                            CFVarChip("{date}")
                        }
                        .buttonStyle(.plain)

                        Button(action: { insertVariable("{time}") }) {
                            CFVarChip("{time}")
                        }
                        .buttonStyle(.plain)

                        Button(action: { insertVariable("{clipboard}") }) {
                            CFVarChip("{clipboard}")
                        }
                        .buttonStyle(.plain)

                        Button(action: { insertVariable("{cursor}") }) {
                            CFVarChip("{cursor}")
                        }
                        .buttonStyle(.plain)
                    }

                    Text(L("editor_variables_hint"))
                        .font(.system(size: 11))
                        .foregroundColor(theme.textMuted)
                }
            }

            Section(L("editor_section_expansion")) {
                Picker(L("editor_expand_after"), selection: $snippet.expandTrigger) {
                    Text(L("trigger_delimiter_long")).tag("delimiter")
                    Text(L("trigger_space_long")).tag("space")
                    Text(L("trigger_any_long")).tag("any")
                    Text(L("trigger_tab_long")).tag("tab")
                    Text(L("trigger_enter_long")).tag("enter")
                }

                Toggle(L("editor_case_sensitive"), isOn: $snippet.caseSensitive)
                Toggle(L("editor_play_sound"), isOn: $snippet.playSound)
            }

            Section(L("editor_section_statistics")) {
                // 2×2 Grid
                HStack(spacing: 12) {
                    VStack(spacing: 12) {
                        CFStatCard(
                            value: "\(snippet.useCount)",
                            label: L("stat_uses")
                        )

                        CFStatCard(
                            value: "\(charsSaved)",
                            label: L("stat_chars_per_use")
                        )
                    }

                    VStack(spacing: 12) {
                        CFStatCard(
                            value: formatTimeSaved(estimatedTimeSaved),
                            label: L("stat_time_saved")
                        )

                        CFStatCard(
                            value: "\(charsSaved * Int(snippet.useCount))",
                            label: L("stat_chars_saved")
                        )
                    }
                }
                .padding(.vertical, 8)
            }

            Section(L("editor_section_apps")) {
                Toggle(L("editor_restrict_apps"), isOn: $snippet.restrictToApps)

                if snippet.restrictToApps {
                    VStack(alignment: .leading, spacing: 8) {
                        if let rules = snippet.appRules, !rules.isEmpty {
                            ForEach(Array(rules), id: \.id) { rule in
                                HStack {
                                    Image(systemName: "app.fill")
                                        .foregroundColor(theme.accent)
                                    Text(rule.appName)
                                    Spacer()
                                    Button(action: { removeAppRule(rule) }) {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(theme.danger)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } else {
                            Text(L("editor_no_apps"))
                                .font(.caption)
                                .foregroundColor(theme.warning)
                        }

                        Button(action: addAppRule) {
                            Label(L("add_app"), systemImage: "plus.circle")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Text(L("editor_restrict_hint"))
                        .font(.caption)
                        .foregroundColor(theme.textMuted)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .toolbar {
            ToolbarItem {
                Button(L("save")) {
                    saveSnippet()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!abbreviationValidation.isValid)
            }

            ToolbarItem {
                Menu {
                    Button(L("duplicate")) {
                        duplicateSnippet()
                    }
                    Divider()
                    Button(L("delete"), role: .destructive) {
                        deleteSnippet()
                    }
                } label: {
                    Label(L("more"), systemImage: "ellipsis.circle")
                }
            }
        }
    }

    private func saveSnippet() {
        snippet.updatedAt = Date()
        try? viewContext.save()
    }

    private func insertVariable(_ variable: String) {
        snippet.content += variable
    }

    private func duplicateSnippet() {
        let duplicate = Snippet(context: viewContext)
        duplicate.id = UUID()
        duplicate.title = snippet.title + " (Copy)"
        duplicate.abbreviation = snippet.abbreviation + "2"
        duplicate.content = snippet.content
        duplicate.isEnabled = snippet.isEnabled
        duplicate.createdAt = Date()
        duplicate.updatedAt = Date()
        duplicate.expandTrigger = snippet.expandTrigger
        duplicate.caseSensitive = snippet.caseSensitive
        duplicate.playSound = snippet.playSound
        duplicate.useCount = 0
        duplicate.group = snippet.group

        try? viewContext.save()
    }

    private func deleteSnippet() {
        viewContext.delete(snippet)
        try? viewContext.save()
    }

    private func addAppRule() {
        // Open app picker
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            // Get bundle identifier
            if let bundle = Bundle(url: url) {
                let bundleID = bundle.bundleIdentifier ?? url.lastPathComponent
                let appName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? url.deletingPathExtension().lastPathComponent

                let rule = AppRule.create(in: viewContext, bundleID: bundleID, appName: appName)
                rule.snippet = snippet

                if snippet.appRules == nil {
                    snippet.appRules = Set()
                }
                snippet.appRules?.insert(rule)

                try? viewContext.save()
            }
        }
    }

    private func removeAppRule(_ rule: AppRule) {
        snippet.appRules?.remove(rule)
        viewContext.delete(rule)
        try? viewContext.save()
    }

    // MARK: - Statistics Helpers
    private var charsSaved: Int {
        let contentLength = snippet.content.count
        let abbreviationLength = snippet.abbreviation.count
        return max(0, contentLength - abbreviationLength)
    }

    private func formatTimeSaved(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        } else if seconds < 3600 {
            let mins = seconds / 60
            return "\(mins)m"
        } else {
            let hours = seconds / 3600
            return "\(hours)h"
        }
    }

    private var estimatedTimeSaved: Int {
        // Estimate 2 seconds saved per expansion (typing time)
        return Int(snippet.useCount) * 2
    }
}

// MARK: - Three Panel Layout
private struct ThreePanelLayout<Left: View, Middle: View, Right: View>: View {
    @ViewBuilder let leftPanel: () -> Left
    @ViewBuilder let middlePanel: () -> Middle
    @ViewBuilder let rightPanel: () -> Right

    @Environment(\.cfTheme) var theme

    var body: some View {
        HStack(spacing: 0) {
            leftPanel()
                .frame(width: 230)
                .background(theme.surfaceAlt)

            Divider()

            middlePanel()
                .frame(maxWidth: .infinity)
                .background(theme.surface)

            Divider()

            rightPanel()
                .frame(width: 280)
                .background(theme.surfaceAlt)
        }
    }
}

// MARK: - Groups Panel
private struct GroupsPanel: View {
    let groups: FetchedResults<SnippetGroup>
    @Binding var selectedGroup: SnippetGroup?
    let onCreateGroup: () -> Void

    @Environment(\.cfTheme) var theme
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Snippet.lastUsed, ascending: false)],
        predicate: NSPredicate(format: "lastUsed != nil"),
        animation: .default)
    private var recentSnippets: FetchedResults<Snippet>

    private var recentSnippetsLimited: [Snippet] {
        Array(recentSnippets.prefix(5))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(L("editor_groups"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.textStrong)

                Spacer()

                CFIconBtn(
                    icon: AnyView(CFIcon(type: .plus, size: 14, stroke: 1.8))
                ) {
                    onCreateGroup()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(theme.fill1)

            Divider()

            // Content
            ScrollView {
                VStack(spacing: 16) {
                    // Library Section
                    if !recentSnippetsLimited.isEmpty {
                        VStack(spacing: 8) {
                            CFSectionLabel(L("editor_library"))
                                .padding(.horizontal, 8)

                            VStack(spacing: 2) {
                                ForEach(recentSnippetsLimited, id: \.id) { snippet in
                                    LibraryRow(
                                        icon: .clock,
                                        iconColor: BrandPalette.Category.recent,
                                        title: snippet.title,
                                        subtitle: snippet.abbreviation
                                    ) {
                                        // TODO: Navigate to snippet
                                    }
                                }
                            }
                        }
                        .padding(.top, 8)
                    }

                    // Groups Section
                    VStack(spacing: 8) {
                        CFSectionLabel(L("editor_groups"))
                            .padding(.horizontal, 8)

                        VStack(spacing: 2) {
                            ForEach(Array(groups), id: \.id) { group in
                                GroupRow(
                                    group: group,
                                    isSelected: selectedGroup?.id == group.id,
                                    action: {
                                        selectedGroup = group
                                    },
                                    onDelete: {
                                        deleteGroup(group)
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(8)
            }
        }
    }

    private func deleteGroup(_ group: SnippetGroup) {
        // If this is the selected group, deselect it
        if selectedGroup?.id == group.id {
            selectedGroup = nil
        }

        // Delete the group from Core Data
        viewContext.delete(group)

        // Save the context
        do {
            try viewContext.save()
        } catch {
            Log.ui.error("Failed to delete group: \(error.localizedDescription, privacy: .public)")
        }
    }
}

private struct LibraryRow: View {
    let icon: CFIcon.IconType
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    @Environment(\.cfTheme) var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(iconColor.opacity(0.18))
                        .frame(width: 22, height: 22)

                    CFIcon(type: icon, size: 12, stroke: 1.6)
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.textStrong)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(theme.textMuted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

private struct GroupRow: View {
    @ObservedObject var group: SnippetGroup
    let isSelected: Bool
    let action: () -> Void
    var onDelete: (() -> Void)? = nil

    @Environment(\.cfTheme) var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                CFIcon(type: .folder, size: 14, stroke: 1.8)
                    .foregroundColor(isSelected ? theme.accent : theme.text)

                Text(group.name)
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? theme.textStrong : theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)

                CFCountBadge(count: group.sortedSnippets.count)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? theme.fill2 : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onDelete = onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label(L("editor_delete_group"), systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Snippets Panel
private struct SnippetsPanel: View {
    let group: SnippetGroup?
    let filteredGroups: [SnippetGroup]
    @Binding var searchText: String
    @Binding var selectedSnippet: Snippet?
    let filteredSnippets: (SnippetGroup) -> [Snippet]
    let onCreateSnippet: () -> Void

    @Environment(\.cfTheme) var theme

    var body: some View {
        VStack(spacing: 0) {
            // Header with search
            VStack(spacing: 12) {
                HStack {
                    Text(L("section_snippets"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.textStrong)

                    Spacer()

                    CFIconBtn(
                        icon: AnyView(CFIcon(type: .plus, size: 14, stroke: 1.8))
                    ) {
                        onCreateSnippet()
                    }
                }

                CFInput(
                    text: $searchText,
                    placeholder: L("editor_search"),
                    prefix: nil,
                    suffix: AnyView(
                        CFIcon(type: .search, size: 14, stroke: 1.6)
                            .foregroundColor(theme.textMuted)
                    )
                )
            }
            .padding(12)
            .background(theme.surface)

            Divider()

            // Snippets List
            ScrollView {
                if let group = group {
                    VStack(spacing: 2) {
                        ForEach(filteredSnippets(group), id: \.id) { snippet in
                            SnippetListRow(
                                snippet: snippet,
                                isSelected: selectedSnippet?.id == snippet.id
                            ) {
                                selectedSnippet = snippet
                            }
                        }
                    }
                    .padding(8)
                } else {
                    // Show all snippets from filtered groups
                    VStack(spacing: 12) {
                        ForEach(filteredGroups, id: \.id) { group in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(group.name)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(theme.textMuted)
                                    .padding(.horizontal, 8)
                                    .padding(.top, 8)

                                VStack(spacing: 2) {
                                    ForEach(filteredSnippets(group), id: \.id) { snippet in
                                        SnippetListRow(
                                            snippet: snippet,
                                            isSelected: selectedSnippet?.id == snippet.id
                                        ) {
                                            selectedSnippet = snippet
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(8)
                }
            }
        }
    }
}

private struct SnippetListRow: View {
    @ObservedObject var snippet: Snippet
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.cfTheme) var theme

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(snippet.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? theme.textStrong : theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(snippet.abbreviation)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(theme.textSubtle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? theme.accent.opacity(0.15) : Color.clear)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isSelected ? theme.accent.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Editor Panel
private struct EditorPanel: View {
    let selectedSnippet: Snippet?

    @Environment(\.cfTheme) var theme

    var body: some View {
        if let snippet = selectedSnippet {
            SnippetDetailView(snippet: snippet)
        } else {
            VStack(spacing: 16) {
                CFIcon(type: .text, size: 48, stroke: 1.4)
                    .foregroundColor(theme.textFaint)

                Text(L("editor_select_snippet"))
                    .font(.system(size: 14))
                    .foregroundColor(theme.textMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Editor Toolbar
private struct EditorToolbar: View {
    let selectedSnippet: Snippet?
    let onNew: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    @Environment(\.cfTheme) var theme

    var body: some View {
        HStack(spacing: 12) {
            // New Button
            Button(action: onNew) {
                HStack(spacing: 6) {
                    CFIcon(type: .plus, size: 12, stroke: 1.8)
                    Text(L("new"))
                        .font(.system(size: 12))
                    Text("⌘N")
                        .font(.system(size: 10))
                        .foregroundColor(theme.textSubtle)
                }
                .foregroundColor(theme.textStrong)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(theme.fill2)
                .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("n", modifiers: .command)

            // Duplicate Button
            Button(action: onDuplicate) {
                HStack(spacing: 6) {
                    CFIcon(type: .bracket, size: 12, stroke: 1.8)
                    Text(L("duplicate"))
                        .font(.system(size: 12))
                }
                .foregroundColor(selectedSnippet == nil ? theme.textFaint : theme.textStrong)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(theme.fill2)
                .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .disabled(selectedSnippet == nil)

            Spacer()

            // Delete Button
            Button(action: onDelete) {
                HStack(spacing: 6) {
                    CFIcon(type: .trash, size: 12, stroke: 1.8)
                    Text(L("delete"))
                        .font(.system(size: 12))
                    Text("⌘⌫")
                        .font(.system(size: 10))
                        .foregroundColor(theme.danger.opacity(0.7))
                }
                .foregroundColor(selectedSnippet == nil ? theme.textFaint : theme.danger)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(theme.fill2)
                .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(selectedSnippet == nil)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(theme.fill1)
    }
}

// MARK: - Editor Status Bar
private struct EditorStatusBar: View {
    let selectedSnippet: Snippet?

    @Environment(\.cfTheme) var theme

    private var contentStats: String {
        guard let snippet = selectedSnippet else {
            return L("editor_no_selection")
        }

        let chars = snippet.content.count
        let words = snippet.content.split(separator: " ").count

        return L("editor_stats", chars, words)
    }

    var body: some View {
        HStack {
            // Left: Content Stats
            Text(contentStats)
                .font(.system(size: 11))
                .foregroundColor(theme.textMuted)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(theme.fill1)
    }
}

#Preview {
    SnippetEditorView()
        .environment(\.managedObjectContext, CoreDataStack.shared.viewContext)
        .cfAutoTheme()
}
