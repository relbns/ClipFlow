import SwiftUI
import UniformTypeIdentifiers

struct BackupSettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var exportDocument: JSONDocument?
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var message: (title: String, body: String)?

    var body: some View {
        SettingsPage {
            CFSettingsRow(label: L("pref_export"), hint: L("pref_export_hint")) {
                CFToolbarBtn(label: L("pref_export_button")) { export() }
            }
            CFSettingsRow(label: L("pref_import"), hint: L("pref_import_hint"), isLast: true) {
                CFToolbarBtn(label: L("pref_import_button")) { showingImporter = true }
            }
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument ?? JSONDocument(data: Data()),
            contentType: .json,
            defaultFilename: "ClipFlow-Snippets-\(Date().formatted(.iso8601.year().month().day()))"
        ) { result in
            if case .failure(let error) = result {
                message = (L("export_failed"), error.localizedDescription)
            }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): importSnippets(from: url)
            case .failure(let error): message = (L("import_failed"), error.localizedDescription)
            }
        }
        .alert(message?.title ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button(L("ok")) { message = nil }
        } message: {
            Text(message?.body ?? "")
        }
    }

    private func export() {
        Task { @MainActor in
            do {
                exportDocument = JSONDocument(data: try await SnippetExporter(context: viewContext).exportAll())
                showingExporter = true
            } catch {
                message = (L("export_failed"), error.localizedDescription)
            }
        }
    }

    private func importSnippets(from url: URL) {
        Task { @MainActor in
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let result = try await SnippetExporter(context: viewContext).importFromJSON(data, mergeStrategy: .skip)
                message = (L("import_complete"), L("import_result", result.imported, result.skipped))
            } catch {
                message = (L("import_failed"), error.localizedDescription)
            }
        }
    }
}

struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
