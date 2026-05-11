import SwiftUI
import CoreData

/// Public wrapper that checks Core Data availability
struct SnippetEditorView: View {
    var body: some View {
        CoreDataAvailabilityWrapper {
            SnippetEditorContentView()
        }
    }
}

/// Internal view with Core Data dependencies
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
        .frame(minWidth: 980, minHeight: 640)
    }

    private func createGroup() {
        print("➕ Creating new group...")
        withAnimation {
            let newGroup = SnippetGroup(context: viewContext)
            newGroup.id = UUID()
            newGroup.name = "New Group"
            newGroup.isEnabled = true
            newGroup.sortOrder = Int32(groups.count)
            newGroup.createdAt = Date()

            do {
                try viewContext.save()
                print("✅ Group created successfully: \(newGroup.name)")
            } catch {
                print("❌ Failed to create group: \(error)")
            }
        }
    }

    private func createSnippet() {
        print("➕ Creating new snippet...")

        guard let group = selectedGroup ?? groups.first else {
            print("❌ No group available! groups.count = \(groups.count)")

            // Create default group if none exists
            print("📂 Creating default group first...")
            let defaultGroup = SnippetGroup(context: viewContext)
            defaultGroup.id = UUID()
            defaultGroup.name = "Default"
            defaultGroup.isEnabled = true
            defaultGroup.sortOrder = 0
            defaultGroup.createdAt = Date()

            do {
                try viewContext.save()
                print("✅ Default group created")
            } catch {
                print("❌ Failed to create default group: \(error)")
                return
            }

            // Try again with the new group
            createSnippet()
            return
        }

        print("📂 Using group: \(group.name)")

        withAnimation {
            let newSnippet = Snippet(context: viewContext)
            newSnippet.id = UUID()
            newSnippet.title = "New Snippet"
            newSnippet.abbreviation = ".new"
            newSnippet.content = ""
            newSnippet.isEnabled = true
            newSnippet.createdAt = Date()
            newSnippet.updatedAt = Date()
            newSnippet.expandTrigger = "delimiter"
            newSnippet.caseSensitive = false
            newSnippet.playSound = false
            newSnippet.useCount = 0
            newSnippet.group = group

            do {
                try viewContext.save()
                selectedSnippet = newSnippet
                print("✅ Snippet created successfully: \(newSnippet.title)")
            } catch {
                print("❌ Failed to create snippet: \(error)")
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
}

private struct SnippetRow: View {
    @ObservedObject var snippet: Snippet

    var body: some View {
        HStack {
            Image(systemName: snippet.isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(snippet.isEnabled ? .green : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(snippet.title)
                    .font(.body)

                Text(snippet.abbreviation)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if snippet.useCount > 0 {
                Text("\(snippet.useCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct SnippetDetailView: View {
    @ObservedObject var snippet: Snippet
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Snippet.abbreviation, ascending: true)],
        animation: .default)
    private var allSnippets: FetchedResults<Snippet>

    private var abbreviationValidation: (isValid: Bool, message: String?) {
        let abbr = snippet.abbreviation.trimmingCharacters(in: .whitespaces)

        if abbr.isEmpty {
            return (false, "Abbreviation cannot be empty")
        }

        let validPrefixes = [".", ";", "/"]
        let hasValidPrefix = validPrefixes.contains(where: { abbr.hasPrefix($0) })
        if !hasValidPrefix {
            return (false, "Must start with . or ; or /")
        }

        if abbr.contains(" ") {
            return (false, "Cannot contain spaces")
        }

        // Allow alphanumerics (includes Hebrew), special chars, and Hebrew letters explicitly
        var allowedCharacters = CharacterSet.alphanumerics
        allowedCharacters.formUnion(CharacterSet(charactersIn: ".;/_-"))
        allowedCharacters.formUnion(CharacterSet(charactersIn: "א...ת"))  // Hebrew letters range

        if abbr.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
            return (false, "Only letters, numbers, Hebrew, and ._-/; allowed")
        }

        let duplicate = allSnippets.first { otherSnippet in
            otherSnippet.id != snippet.id && otherSnippet.abbreviation == abbr
        }
        if duplicate != nil {
            return (false, "This abbreviation already exists")
        }

        return (true, nil)
    }

    var body: some View {
        Form {
            Section("Basic") {
                TextField("Title:", text: $snippet.title)

                VStack(alignment: .leading, spacing: 4) {
                    TextField("Abbreviation:", text: $snippet.abbreviation)
                        .help("Type this to expand the snippet (e.g., .cdsh)")

                    if let message = abbreviationValidation.message {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text(message)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    } else if !snippet.abbreviation.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("Valid abbreviation")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }

                Toggle("Enabled", isOn: $snippet.isEnabled)
            }

            Section("Content") {
                TextEditor(text: $snippet.content)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200)
                    .environment(\.layoutDirection, snippet.content.isRTL ? .rightToLeft : .leftToRight)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        CFVarChip(text: "{date}") {
                            insertVariable("{date}")
                        }
                        CFVarChip(text: "{time}") {
                            insertVariable("{time}")
                        }
                        CFVarChip(text: "{clipboard}") {
                            insertVariable("{clipboard}")
                        }
                        CFVarChip(text: "{cursor}") {
                            insertVariable("{cursor}")
                        }
                    }

                    Text("Click to insert variables · Type {prompt:Name} for user input")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Section("Expansion") {
                Picker("Expand after:", selection: $snippet.expandTrigger) {
                    Text("Delimiter (space, tab, punct)").tag("delimiter")
                    Text("Space only").tag("space")
                    Text("Any character").tag("any")
                    Text("Tab only").tag("enter")
                }

                Toggle("Case sensitive", isOn: $snippet.caseSensitive)
                Toggle("Play sound on expansion", isOn: $snippet.playSound)
            }

            Section("Statistics") {
                // 2×2 Grid
                HStack(spacing: 12) {
                    VStack(spacing: 12) {
                        CFStatCard(
                            value: "\(snippet.useCount)",
                            label: "TOTAL USES"
                        )

                        CFStatCard(
                            value: "\(charsSaved)",
                            label: "CHARS/USE"
                        )
                    }

                    VStack(spacing: 12) {
                        CFStatCard(
                            value: formatTimeSaved(estimatedTimeSaved),
                            label: "TIME SAVED"
                        )

                        CFStatCard(
                            value: "\(charsSaved * Int(snippet.useCount))",
                            label: "TOTAL SAVED"
                        )
                    }
                }
                .padding(.vertical, 8)
            }

            Section("App-Specific Rules") {
                Toggle("Restrict to specific apps", isOn: $snippet.restrictToApps)

                if snippet.restrictToApps {
                    VStack(alignment: .leading, spacing: 8) {
                        if let rules = snippet.appRules, !rules.isEmpty {
                            ForEach(Array(rules), id: \.id) { rule in
                                HStack {
                                    Image(systemName: "app.fill")
                                        .foregroundColor(.blue)
                                    Text(rule.appName)
                                    Spacer()
                                    Button(action: { removeAppRule(rule) }) {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } else {
                            Text("No apps selected. This snippet will not expand anywhere.")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }

                        Button(action: addAppRule) {
                            Label("Add App", systemImage: "plus.circle")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Text("Snippet will only expand in selected applications")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .toolbar {
            ToolbarItem {
                Button("Save") {
                    saveSnippet()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!abbreviationValidation.isValid)
            }

            ToolbarItem {
                Menu {
                    Button("Duplicate") {
                        duplicateSnippet()
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        deleteSnippet()
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
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
                Text("Groups")
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
                            CFSectionLabel("LIBRARY")
                                .padding(.horizontal, 8)

                            VStack(spacing: 2) {
                                ForEach(recentSnippetsLimited, id: \.id) { snippet in
                                    LibraryRow(
                                        icon: .clock,
                                        iconColor: Color(red: 0.78, green: 0.14, blue: 0.70),
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
                        CFSectionLabel("GROUPS")
                            .padding(.horizontal, 8)

                        VStack(spacing: 2) {
                            ForEach(Array(groups), id: \.id) { group in
                                GroupRow(
                                    group: group,
                                    isSelected: selectedGroup?.id == group.id
                                ) {
                                    selectedGroup = group
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
                    Text("Snippets")
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
                    placeholder: "Search snippets...",
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

                Text("Select a snippet to edit")
                    .font(.system(size: 14))
                    .foregroundColor(theme.textMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    SnippetEditorView()
        .environment(\.managedObjectContext, CoreDataStack.shared.viewContext)
        .cfAutoTheme()
}
