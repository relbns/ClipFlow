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

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(selection: $selectedSnippet) {
                ForEach(groups) { group in
                    Section(header: Text(group.name)) {
                        ForEach(group.sortedSnippets, id: \.id) { snippet in
                            SnippetRow(snippet: snippet)
                                .tag(snippet)
                        }
                    }
                }
            }
            .navigationTitle("Snippets")
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

    var body: some View {
        Form {
            Section("Basic") {
                TextField("Title:", text: $snippet.title)

                TextField("Abbreviation:", text: $snippet.abbreviation)
                    .help("Type this to expand the snippet (e.g., .cdsh)")

                Toggle("Enabled", isOn: $snippet.isEnabled)
            }

            Section("Content") {
                TextEditor(text: $snippet.content)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200)
                    .environment(\.layoutDirection, snippet.content.isRTL ? .rightToLeft : .leftToRight)

                Text("Use {date}, {time}, {clipboard} for dynamic content")
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
            }
        }
    }

    private func saveSnippet() {
        snippet.updatedAt = Date()
        try? viewContext.save()
    }
}

#Preview {
    SnippetEditorView()
        .environment(\.managedObjectContext, CoreDataStack.shared.viewContext)
}
