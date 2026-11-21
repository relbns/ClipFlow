import AppKit
import CoreData
import SwiftUI

/// The groups this Mac shares or joined in team folders, with their status, and joining another one.
struct SharedGroupsSettingsRow: View {
    @ObservedObject private var sharedGroups = SharedGroups.shared
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.cfTheme) private var theme
    @State private var error: String?

    var body: some View {
        CFSettingsRow(label: L("shared_groups"), hint: L("shared_groups_hint")) {
            VStack(alignment: .leading, spacing: 8) {
                if sharedGroups.groups.isEmpty {
                    Text(L("shared_none")).font(.system(size: 12)).foregroundColor(theme.textMuted)
                }
                ForEach(sharedGroups.groups, id: \.folder) { group in
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name(of: group)).font(.system(size: 12, weight: .medium)).foregroundColor(theme.textStrong)
                            Text(Self.displayPath(group.folder)).font(.system(size: 11)).foregroundColor(theme.textMuted)
                                .lineLimit(1).truncationMode(.middle)
                            Text(status(of: group)).font(.system(size: 11)).foregroundColor(theme.textSubtle)
                        }
                        Spacer(minLength: 8)
                        CFToolbarBtn(label: L("editor_stop_sharing")) { sharedGroups.stopSharing(folder: group.folder) }
                    }
                }
                CFToolbarBtn(label: L("shared_join")) { join() }
            }
        }
        .alert(L("shared_failed"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button(L("ok")) { error = nil }
        } message: {
            Text(error ?? "")
        }
    }

    private func name(of group: SharedGroup) -> String {
        guard let id = group.groupID.flatMap(UUID.init(uuidString:)) else { return L("shared_waiting") }
        let request = SnippetGroup.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return (try? viewContext.fetch(request).first?.name) ?? L("shared_waiting")
    }

    private func status(of group: SharedGroup) -> String {
        switch sharedGroups.statuses[group.folder] ?? .off {
        case .off: return L("sync_status_waiting")
        case .syncing: return L("sync_status_syncing")
        case .synced(let date, let others):
            let people = others == 0 ? L("sync_other_macs_none") : L("sync_other_macs", count: others)
            return L("sync_status_synced", date.formatted(date: .omitted, time: .shortened)) + " · " + people
        case .failed(let reason): return L("sync_status_failed", reason)
        }
    }

    private func join() {
        guard let folder = Self.chooseFolder(prompt: L("shared_join_prompt")) else { return }
        do { try sharedGroups.join(folder) } catch { self.error = error.localizedDescription }
    }

    static func chooseFolder(prompt: String) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = prompt
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func displayPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path
            .replacingOccurrences(of: "\(home)/Library/Mobile Documents/com~apple~CloudDocs", with: "iCloud Drive")
            .replacingOccurrences(of: "\(home)/Library/CloudStorage/", with: "")
            .replacingOccurrences(of: home, with: "~")
    }
}
