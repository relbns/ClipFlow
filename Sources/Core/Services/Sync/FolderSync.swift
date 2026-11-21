import AppKit
import Combine
import CoreData
import IOKit
import SystemConfiguration

/// Syncs snippets, groups, pinned text and settings through a folder that a cloud service keeps in step between
/// Macs: iCloud Drive by default, or a folder shared with another Apple ID, Google Drive or Dropbox for Macs on
/// different accounts. Each Mac writes only `devices/<its id>.json` and reads the others.
@MainActor
final class FolderSync: ObservableObject {
    static let shared = FolderSync()

    static let enabledKey = "syncEnabled"
    static let folderKey = "syncFolderPath"
    static let settingsKey = "syncSettings"
    static let pinsKey = "syncPins"
    private static let deviceIDKey = "syncDeviceID"

    enum Status: Equatable {
        case off
        case syncing
        case synced(Date, otherMacs: Int)
        case failed(String)
    }

    @Published private(set) var status: Status = .off

    private var store: SyncStore?
    private var defaults: UserDefaults = .standard
    private var timer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    private var isSyncing = false
    private var pending = false
    private var joinWaitStarted: Date?

    static var defaultFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/ClipFlow", isDirectory: true)
    }

    var folder: URL {
        defaults.string(forKey: Self.folderKey).map { URL(fileURLWithPath: $0, isDirectory: true) } ?? Self.defaultFolder
    }

    var isEnabled: Bool { defaults.bool(forKey: Self.enabledKey) }

    private static let joinedKey = "syncJoined"

    /// Whether this Mac has once synced with the other Macs' files present; until then its copies of their snippets
    /// fold into theirs.
    private var hasJoined: Bool { defaults.bool(forKey: Self.joinedKey) }

    /// This Mac's file in `devices/`, once it has an id.
    var deviceFileName: String? { defaults.string(forKey: Self.deviceIDKey).map { "\($0).json" } }

    private var kinds: Set<String> {
        var kinds: Set<String> = ["group", "snippet"]
        if defaults.bool(forKey: Self.settingsKey) { kinds.insert("setting") }
        if defaults.bool(forKey: Self.pinsKey) { kinds.insert("pin") }
        return kinds
    }

    private static let deviceHardwareKey = "syncDeviceHardware"

    /// This Mac's id in the folder. Migration Assistant copies preferences to a new Mac, so the id is tied to the
    /// hardware: on another Mac it is replaced, and the copied ledger is dropped with it.
    private var deviceID: String {
        let hardware = hardwareID
        if let id = defaults.string(forKey: Self.deviceIDKey) {
            switch defaults.string(forKey: Self.deviceHardwareKey) {
            case hardware?: return id
            case nil:
                // Written before the hardware check existed: this is the same Mac.
                defaults.set(hardware, forKey: Self.deviceHardwareKey)
                return id
            default: break
            }
        }
        if defaults.string(forKey: Self.deviceIDKey) != nil {
            try? FileManager.default.removeItem(at: ledgerURL)
            defaults.removeObject(forKey: Self.joinedKey)
        }
        let id = UUID().uuidString
        defaults.set(id, forKey: Self.deviceIDKey)
        defaults.set(hardware, forKey: Self.deviceHardwareKey)
        return id
    }

    private let ledgerURL: URL
    private let hardwareID: String
    private lazy var computerName: String = {
        (SCDynamicStoreCopyComputerName(nil, nil) as String?) ?? "Mac"
    }()

    init(ledgerDirectory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("ClipFlow"), hardwareID: String = FolderSync.platformUUID()) {
        ledgerURL = ledgerDirectory.appendingPathComponent("sync-ledger.json")
        self.hardwareID = hardwareID
    }

    nonisolated static func platformUUID() -> String {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(service) }
        let value = IORegistryEntryCreateCFProperty(service, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0)
        return (value?.takeRetainedValue() as? String) ?? "unknown"
    }

    func configure(store: SyncStore, defaults: UserDefaults) {
        self.store = store
        self.defaults = defaults
    }

    /// Sync runs in a context of its own, so its saves never commit the Snippet Editor's unsaved edits.
    func start(context: NSManagedObjectContext, monitor: ClipboardMonitor, defaults: UserDefaults = .standard) {
        configure(store: SyncStore(context: context, monitor: monitor, defaults: defaults), defaults: defaults)
        cancellables = []
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .filter { Self.touchesSyncedData($0) }
            .map { _ in () }
            .merge(with: NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification).map { _ in () })
            .debounce(for: .seconds(3), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.syncSoon() }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .merge(with: NotificationCenter.default.publisher(for: .clipPinsChanged))
            .sink { [weak self] _ in self?.syncSoon() }
            .store(in: &cancellables)
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.syncSoon() }
        }
        syncSoon()
    }

    func syncSoon() {
        guard isEnabled else {
            if status != .off { status = .off }
            joinWaitStarted = nil
            return
        }
        if isSyncing {
            pending = true
            return
        }
        Task { await sync() }
    }

    func sync() async {
        guard isEnabled, let store, !isSyncing else { return }
        isSyncing = true
        defer {
            isSyncing = false
            if pending {
                pending = false
                syncSoon()
            }
        }
        if case .synced = status {} else { status = .syncing }
        do {
            let deviceID = self.deviceID
            let devices = folder.appendingPathComponent("devices", isDirectory: true)
            try FileManager.default.createDirectory(at: devices, withIntermediateDirectories: true)
            let (remoteFiles, downloading) = try readOtherDevices(in: devices, deviceID: deviceID)
            let remote = remoteFiles.flatMap(\.records)
            let kinds = self.kinds
            var ledger = readLedger()

            if ledger.isEmpty {
                // Joining: give the other Macs' files up to two minutes to download before this Mac's state counts.
                if downloading > 0 {
                    let started = joinWaitStarted ?? Date()
                    joinWaitStarted = started
                    if Date().timeIntervalSince(started) < 120 { return }
                }
                // What this Mac has counts as old, except snippet edits, which keep their own time, so joining a
                // folder again neither spreads stale copies nor reverts edits made since.
                ledger = SyncMerge.stamp(local: store.export(kinds: kinds), ledger: [:], kinds: kinds, now: .distantPast, device: deviceID)
                for (key, time) in store.snippetEditTimes() where ledger[key] != nil { ledger[key]?.modifiedAt = time }
            } else {
                ledger = SyncMerge.stamp(local: store.export(kinds: kinds), ledger: ledger, kinds: kinds, now: Date(), device: deviceID)
            }
            joinWaitStarted = nil

            let result = try apply(
                SyncMerge.incoming(remote: remote, ledger: ledger, kinds: kinds), to: &ledger, store: store,
                deletedGroups: SyncMerge.deletedGroups(remote: remote, ledger: ledger)
            )
            var keepTime = result.detached
            // Until this Mac has seen the other Macs' files once, its copies of their snippets and groups fold into
            // theirs. The fold is not an edit: it is stamped just after the version it replaces, so a newer edit made
            // on another Mac still wins.
            if !hasJoined, !remoteFiles.isEmpty {
                let duplicates = SyncMerge.duplicates(local: store.export(kinds: kinds), remote: remote, ledger: ledger)
                guard store.dropSnippets(duplicates.dropSnippets) else { throw SyncError.saveFailed }
                let fold = store.foldGroups(duplicates.groupMap)
                guard fold.saved else { throw SyncError.saveFailed }
                for key in duplicates.dropSnippets.union(fold.removedGroups) {
                    guard let entry = ledger[key], !entry.deleted else { continue }
                    ledger[key] = SyncLedgerEntry(hash: "", modifiedAt: entry.modifiedAt.addingTimeInterval(0.001), deleted: true, device: deviceID)
                }
                keepTime.formUnion(fold.movedSnippets)
                defaults.set(true, forKey: Self.joinedKey)
            }

            let local = store.export(kinds: kinds)
            for key in keepTime {
                if let payload = local[key] { ledger[key]?.hash = payload.stableHash }
            }
            ledger = SyncMerge.stamp(local: local, ledger: ledger, kinds: kinds, now: Date(), device: deviceID, skip: result.deferred)

            let file = SyncDeviceFile(
                deviceID: deviceID, deviceName: computerName, writtenAt: Date(),
                records: SyncMerge.records(ledger: ledger, local: store.export(kinds: kinds))
            )
            try write(file, to: devices.appendingPathComponent("\(deviceID).json"))
            try writeLedger(ledger)
            status = .synced(Date(), otherMacs: remoteFiles.count)
        } catch {
            status = .failed(error.localizedDescription)
            Log.storage.error("Sync failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    enum SyncError: LocalizedError {
        case saveFailed
        var errorDescription: String? { "The changes from the other Macs could not be saved." }
    }

    /// Applies remote winners and records them in the ledger as already seen, so they are not echoed as local edits.
    /// A failed save stops the sync before anything is written, so a rolled-back state is never published.
    private func apply(
        _ incoming: [SyncRecord], to ledger: inout [String: SyncLedgerEntry], store: SyncStore, deletedGroups: Set<String>
    ) throws -> SyncStore.ApplyResult {
        guard !incoming.isEmpty else { return SyncStore.ApplyResult(saved: true, deferred: [], detached: []) }
        let result = store.apply(incoming, deletedGroups: deletedGroups)
        guard result.saved else { throw SyncError.saveFailed }
        for record in incoming where !result.deferred.contains(record.key) {
            ledger[record.key] = SyncLedgerEntry(
                hash: record.payload?.stableHash ?? "", modifiedAt: record.modifiedAt, deleted: record.deleted, device: record.device
            )
        }
        Log.storage.info("Sync applied \(incoming.count - result.deferred.count, privacy: .public) changes from other Macs")
        return result
    }

    /// Changes to snippets, groups or app rules can need a sync; a snippet's use count (the stats context) cannot.
    /// Pins announce themselves with `.clipPinsChanged`, so history saves do not start a sync.
    nonisolated private static func touchesSyncedData(_ notification: Notification) -> Bool {
        if (notification.object as? NSManagedObjectContext)?.name == CoreDataStack.statsContextName { return false }
        let synced: Set<String> = ["Snippet", "SnippetGroup", "AppRule"]
        let info = notification.userInfo ?? [:]
        for key in [NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey] {
            guard let objects = info[key] as? Set<NSManagedObject> else { continue }
            if objects.contains(where: { synced.contains($0.entity.name ?? "") }) { return true }
        }
        return false
    }

    // MARK: - Files

    /// The other Macs' files, and how many are still downloading. A file whose name is not its own device id is a
    /// conflict copy a cloud service made (`<id> 2.json`) and is skipped.
    private func readOtherDevices(in devices: URL, deviceID: String) throws -> (files: [SyncDeviceFile], downloading: Int) {
        let names = try FileManager.default.contentsOfDirectory(atPath: devices.path)
        var files: [SyncDeviceFile] = []
        var downloading = 0
        for name in names {
            let url = devices.appendingPathComponent(name)
            // iCloud Drive keeps a file it has not downloaded yet as ".<name>.icloud"; ask for it and read it next time.
            if name.hasPrefix("."), name.hasSuffix(".icloud") {
                let real = devices.appendingPathComponent(String(name.dropFirst().dropLast(".icloud".count)))
                try? FileManager.default.startDownloadingUbiquitousItem(at: real)
                if real.lastPathComponent != "\(deviceID).json" { downloading += 1 }
                continue
            }
            guard name.hasSuffix(".json"), name != "\(deviceID).json",
                  let data = try? Data(contentsOf: url),
                  let file = try? JSONDecoder.sync.decode(SyncDeviceFile.self, from: data), file.version == 1,
                  name == "\(file.deviceID).json" else { continue }
            files.append(file)
        }
        return (files, downloading)
    }

    private func write(_ file: SyncDeviceFile, to url: URL) throws {
        let encoder = JSONEncoder.sync
        let data = try encoder.encode(file)
        if let existing = try? Data(contentsOf: url),
           let old = try? JSONDecoder.sync.decode(SyncDeviceFile.self, from: existing), old.records == file.records { return }
        try data.write(to: url, options: .atomic)
    }

    private func readLedger() -> [String: SyncLedgerEntry] {
        guard let data = try? Data(contentsOf: ledgerURL) else { return [:] }
        return (try? JSONDecoder.sync.decode([String: SyncLedgerEntry].self, from: data)) ?? [:]
    }

    private func writeLedger(_ ledger: [String: SyncLedgerEntry]) throws {
        try FileManager.default.createDirectory(at: ledgerURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder.sync.encode(ledger).write(to: ledgerURL, options: .atomic)
    }

    /// Forgets what this Mac synced, so turning sync on again (or choosing another folder) joins it afresh.
    func reset() {
        try? FileManager.default.removeItem(at: ledgerURL)
        defaults.removeObject(forKey: Self.joinedKey)
        joinWaitStarted = nil
        status = .off
    }
}

/// Dates are stored as exact seconds since 1970: ISO 8601 drops the fraction, and a timestamp that changes on its
/// way through a file would make an old record look new.
extension JSONEncoder {
    static var sync: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}

extension JSONDecoder {
    static var sync: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }
}
