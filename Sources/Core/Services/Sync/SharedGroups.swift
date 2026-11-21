import CoreData
import Foundation

/// A snippet group shared through a folder of its own (a shared Dropbox or Google Drive folder, a file server), so
/// a team keeps one set of snippets. Each Mac that shares or joins it syncs only that group there.
struct SharedGroup: Codable, Equatable {
    var folder: String
    /// Nil until a Mac that joined the folder has seen the group in it.
    var groupID: String?
}

@MainActor
final class SharedGroups: ObservableObject {
    static let shared = SharedGroups()
    static let defaultsKey = "sharedGroups"

    enum ShareError: LocalizedError {
        case alreadyShared
        case folderHoldsAnotherGroup
        case librarySyncFolder

        var errorDescription: String? {
            switch self {
            case .alreadyShared: return "This group or folder is already shared."
            case .folderHoldsAnotherGroup: return "This folder already holds a shared group. Join it, or choose an empty folder."
            case .librarySyncFolder: return "This is the folder that syncs your whole library between your Macs. Choose a folder of its own."
            }
        }
    }

    @Published private(set) var groups: [SharedGroup] = []
    @Published private(set) var statuses: [String: FolderSync.Status] = [:]

    private var channels: [String: FolderSync] = [:]
    private var context: NSManagedObjectContext?
    private weak var monitor: ClipboardMonitor?
    private var defaults: UserDefaults = .standard
    private var ledgerDirectory: URL?

    func start(context: NSManagedObjectContext, monitor: ClipboardMonitor, defaults: UserDefaults = .standard, ledgerDirectory: URL? = nil) {
        self.context = context
        self.monitor = monitor
        self.defaults = defaults
        self.ledgerDirectory = ledgerDirectory
        groups = Self.load(from: defaults)
        groups.forEach(startChannel)
    }

    func isShared(_ groupID: UUID) -> Bool {
        groups.contains { $0.groupID == groupID.uuidString }
    }

    func folder(of groupID: UUID) -> String? {
        groups.first { $0.groupID == groupID.uuidString }?.folder
    }

    /// Starts sharing a group of this Mac in `folder`, which must not hold another group.
    func share(_ groupID: UUID, in folder: URL) throws {
        let path = Self.normalized(folder)
        try checkNotLibraryFolder(path)
        guard !groups.contains(where: { $0.groupID == groupID.uuidString || $0.folder == path }) else { throw ShareError.alreadyShared }
        let found = Self.groupsInFolder(folder)
        if found.several || (found.id.map { $0 != groupID.uuidString } ?? false) { throw ShareError.folderHoldsAnotherGroup }
        add(SharedGroup(folder: path, groupID: groupID.uuidString))
    }

    /// Joins a group someone shared in `folder`; it appears here on the first sync.
    func join(_ folder: URL) throws {
        let path = Self.normalized(folder)
        try checkNotLibraryFolder(path)
        guard !groups.contains(where: { $0.folder == path }) else { throw ShareError.alreadyShared }
        add(SharedGroup(folder: path, groupID: nil))
    }

    /// The library channel writes this Mac's file under the same device id, so the two would overwrite each other.
    private func checkNotLibraryFolder(_ path: String) throws {
        if path == Self.normalized(FolderSync.shared.folder) { throw ShareError.librarySyncFolder }
    }

    static func normalized(_ folder: URL) -> String {
        folder.resolvingSymlinksInPath().standardizedFileURL.path
    }

    /// Stops syncing the group here; the folder and the other Macs keep it, and so does this Mac's copy.
    func stopSharing(folder: String) {
        channels[folder]?.stop()
        channels[folder]?.reset()
        channels[folder] = nil
        statuses[folder] = nil
        groups.removeAll { $0.folder == folder }
        save()
    }

    func syncAll() async {
        for channel in channels.values { await channel.sync() }
    }

    private func add(_ group: SharedGroup) {
        groups.append(group)
        save()
        startChannel(group)
    }

    private func startChannel(_ group: SharedGroup) {
        guard let context, let monitor else { return }
        let channel = ledgerDirectory.map { FolderSync(ledgerDirectory: $0, sharedGroup: group) } ?? FolderSync(sharedGroup: group)
        let folder = group.folder
        channel.onGroupLearned = { [weak self] id in
            guard let self, let index = self.groups.firstIndex(where: { $0.folder == folder }) else { return }
            self.groups[index].groupID = id
            self.save()
        }
        channel.onGroupGone = { [weak self] in
            Log.storage.info("A shared group was deleted on this Mac; sharing it stops here")
            self?.stopSharing(folder: folder)
        }
        channel.$status
            .receive(on: RunLoop.main)
            .sink { [weak self, weak channel] status in
                guard let self, let channel, self.channels[folder] === channel else { return }
                self.statuses[folder] = status
            }
            .store(in: &channel.observers)
        channels[folder] = channel
        channel.start(context: context, monitor: monitor, defaults: defaults)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(groups) else { return }
        defaults.set(String(decoding: data, as: UTF8.self), forKey: Self.defaultsKey)
    }

    static func load(from defaults: UserDefaults) -> [SharedGroup] {
        guard let text = defaults.string(forKey: defaultsKey) else { return [] }
        return (try? JSONDecoder().decode([SharedGroup].self, from: Data(text.utf8))) ?? []
    }

    /// The group already published in `folder`, if any.
    static func groupInFolder(_ folder: URL) -> String? {
        groupsInFolder(folder).id
    }

    static func groupsInFolder(_ folder: URL) -> (id: String?, several: Bool) {
        let devices = folder.appendingPathComponent("devices", isDirectory: true)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: devices.path)) ?? []
        let records = names.filter { $0.hasSuffix(".json") }.compactMap { name -> [SyncRecord]? in
            guard let data = try? Data(contentsOf: devices.appendingPathComponent(name)) else { return nil }
            return (try? JSONDecoder.sync.decode(SyncDeviceFile.self, from: data))?.records
        }.flatMap { $0 }
        return SyncMerge.sharedGroupID(in: records)
    }
}
