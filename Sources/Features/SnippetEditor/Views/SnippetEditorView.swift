import SwiftUI
import CoreData

struct SnippetEditorView: View {
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
        NavigationSplitView {
            // Sidebar
            List(selection: $selectedSnippet) {
                ForEach(filteredGroups, id: \.id) { group in
                    Section(header: Text(group.name)) {
                        ForEach(filteredSnippets(for: group), id: \.id) { snippet in
                            SnippetRow(snippet: snippet)
                                .tag(snippet)
                        }
                    }
                }
            }
            .navigationTitle("Snippets")
            .searchable(text: $searchText, prompt: "Search snippets...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("New Group") {
                            createGroup()
                        }
                        Button("New Snippet") {
                            createSnippet()
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
        } detail: {
            // Detail
            if let snippet = selectedSnippet {
                SnippetDetailView(snippet: snippet)
            } else {
                Text("Select a snippet to edit")
                    .foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }

    private func createGroup() {
        withAnimation {
            let newGroup = SnippetGroup(context: viewContext)
            newGroup.id = UUID()
            newGroup.name = "New Group"
            newGroup.isEnabled = true
            newGroup.sortOrder = Int32(groups.count)
            newGroup.createdAt = Date()

            try? viewContext.save()
        }
    }

    private func createSnippet() {
        guard let group = selectedGroup ?? groups.first else { return }

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

            try? viewContext.save()
            selectedSnippet = newSnippet
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

struct SnippetRow: View {
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

struct SnippetDetailView: View {
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

                HStack(spacing: 8) {
                    Button(action: { insertVariable("{date}") }) {
                        Label("Date", systemImage: "calendar")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(action: { insertVariable("{time}") }) {
                        Label("Time", systemImage: "clock")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(action: { insertVariable("{clipboard}") }) {
                        Label("Clipboard", systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(action: { insertVariable("{cursor}") }) {
                        Label("Cursor", systemImage: "cursorarrow.click")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer()
                }

                Text("Use variables for dynamic content")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Expansion") {
                Picker("Expand after:", selection: $snippet.expandTrigger) {
                    Text("Delimiter (space, tab, punct)").tag("delimiter")
                    Text("Space only").tag("space")
                    Text("Any character").tag("any")
                    Text("Tab only").tag("tab")
                    Text("Enter only").tag("enter")
                }

                Toggle("Case sensitive", isOn: $snippet.caseSensitive)
                Toggle("Play sound on expansion", isOn: $snippet.playSound)
            }

            if snippet.useCount > 0 {
                Section("Statistics") {
                    LabeledContent("Times used:", value: "\(snippet.useCount)")

                    if let lastUsed = snippet.lastUsed {
                        LabeledContent("Last used:", value: lastUsed.formatted())
                    }
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
}

#Preview {
    SnippetEditorView()
        .environment(\.managedObjectContext, CoreDataStack.shared.viewContext)
}
