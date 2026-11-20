import AppKit
import Combine
import CoreData

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

    static var defaultFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/ClipFlow", isDirectory: true)
    }

    var folder: URL {
        defaults.string(forKey: Self.folderKey).map { URL(fileURLWithPath: $0, isDirectory: true) } ?? Self.defaultFolder
    }

    var isEnabled: Bool { defaults.bool(forKey: Self.enabledKey) }

    private var kinds: Set<String> {
        var kinds: Set<String> = ["group", "snippet"]
        if defaults.bool(forKey: Self.settingsKey) { kinds.insert("setting") }
        if defaults.bool(forKey: Self.pinsKey) { kinds.insert("pin") }
        return kinds
    }

    private var deviceID: String {
        if let id = defaults.string(forKey: Self.deviceIDKey) { return id }
        let id = UUID().uuidString
        defaults.set(id, forKey: Self.deviceIDKey)
        return id
    }

    private let ledgerURL: URL

    init(ledgerDirectory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("ClipFlow")) {
        ledgerURL = ledgerDirectory.appendingPathComponent("sync-ledger.json")
    }

    func configure(store: SyncStore, defaults: UserDefaults) {
        self.store = store
        self.defaults = defaults
    }

    func start(context: NSManagedObjectContext, monitor: ClipboardMonitor, defaults: UserDefaults = .standard) {
        configure(store: SyncStore(context: context, monitor: monitor, defaults: defaults), defaults: defaults)
        cancellables = []
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .merge(with: NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification))
            .debounce(for: .seconds(3), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.syncSoon() }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
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
            let devices = folder.appendingPathComponent("devices", isDirectory: true)
            try FileManager.default.createDirectory(at: devices, withIntermediateDirectories: true)
            let remoteFiles = try readOtherDevices(in: devices)
            let remote = remoteFiles.flatMap(\.records)
            let kinds = self.kinds
            var ledger = readLedger()

            if ledger.isEmpty, !remote.isEmpty {
                let join = SyncMerge.firstJoin(local: store.export(kinds: kinds), remote: remote)
                _ = store.applyFirstJoin(dropSnippets: join.dropSnippets, groupMap: join.groupMap)
                ledger = SyncMerge.stamp(local: store.export(kinds: kinds), ledger: [:], kinds: kinds, now: .distantPast, device: deviceID)
                apply(SyncMerge.incoming(remote: remote, ledger: ledger, kinds: kinds), to: &ledger, store: store)
                store.foldGroups(join.groupMap)
            } else {
                ledger = SyncMerge.stamp(local: store.export(kinds: kinds), ledger: ledger, kinds: kinds, now: Date(), device: deviceID)
                apply(SyncMerge.incoming(remote: remote, ledger: ledger, kinds: kinds), to: &ledger, store: store)
            }
            ledger = SyncMerge.stamp(local: store.export(kinds: kinds), ledger: ledger, kinds: kinds, now: Date(), device: deviceID)
            ledger = SyncMerge.pruned(ledger, now: Date())

            let file = SyncDeviceFile(
                deviceID: deviceID, deviceName: Host.current().localizedName ?? "Mac", writtenAt: Date(),
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

    /// Applies remote winners and records them in the ledger as already seen, so they are not echoed as local edits.
    private func apply(_ incoming: [SyncRecord], to ledger: inout [String: SyncLedgerEntry], store: SyncStore) {
        guard !incoming.isEmpty else { return }
        store.apply(incoming)
        for record in incoming {
            ledger[record.key] = SyncLedgerEntry(
                hash: record.payload?.stableHash ?? "", modifiedAt: record.modifiedAt, deleted: record.deleted, device: record.device
            )
        }
        Log.storage.info("Sync applied \(incoming.count, privacy: .public) changes from other Macs")
    }

    // MARK: - Files

    private func readOtherDevices(in devices: URL) throws -> [SyncDeviceFile] {
        let names = try FileManager.default.contentsOfDirectory(atPath: devices.path)
        var files: [SyncDeviceFile] = []
        for name in names {
            let url = devices.appendingPathComponent(name)
            // iCloud Drive keeps a file it has not downloaded yet as ".<name>.icloud"; ask for it and read it next time.
            if name.hasPrefix("."), name.hasSuffix(".icloud") {
                let real = devices.appendingPathComponent(String(name.dropFirst().dropLast(".icloud".count)))
                try? FileManager.default.startDownloadingUbiquitousItem(at: real)
                continue
            }
            guard name.hasSuffix(".json"), name != "\(deviceID).json",
                  let data = try? Data(contentsOf: url),
                  let file = try? JSONDecoder.sync.decode(SyncDeviceFile.self, from: data), file.version == 1 else { continue }
            files.append(file)
        }
        return files
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
