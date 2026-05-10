import Foundation
import CoreData
import Combine

@MainActor
class iCloudSyncService: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?

    private let context: NSManagedObjectContext
    private let containerURL: URL?
    private var syncTimer: Timer?

    init(context: NSManagedObjectContext) {
        self.context = context
        self.containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents/ClipFlow")
    }

    func enableAutoSync() {
        guard syncTimer == nil else { return }

        syncTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                await self.sync()
            }
        }

        print("☁️ iCloud auto-sync enabled")
    }

    func disableAutoSync() {
        syncTimer?.invalidate()
        syncTimer = nil
        print("☁️ iCloud auto-sync disabled")
    }

    func sync() async {
        guard let containerURL = containerURL else {
            syncError = SyncError.iCloudNotAvailable
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        do {
            // Create iCloud directory if needed
            try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)

            // Export current snippets
            let exporter = SnippetExporter(context: context)
            let data = try await exporter.exportAll()

            // Write to iCloud
            let syncFileURL = containerURL.appendingPathComponent("snippets.json")
            try data.write(to: syncFileURL)

            lastSyncDate = Date()
            print("☁️ Synced to iCloud: \(syncFileURL.path)")
        } catch {
            syncError = error
            print("❌ iCloud sync failed: \(error)")
        }
    }

    func restoreFromiCloud() async throws {
        guard let containerURL = containerURL else {
            throw SyncError.iCloudNotAvailable
        }

        let syncFileURL = containerURL.appendingPathComponent("snippets.json")

        guard FileManager.default.fileExists(atPath: syncFileURL.path) else {
            throw SyncError.noBackupFound
        }

        let data = try Data(contentsOf: syncFileURL)

        let exporter = SnippetExporter(context: context)
        _ = try await exporter.importFromJSON(data, mergeStrategy: .overwrite)

        print("☁️ Restored from iCloud")
    }
}

enum SyncError: Error, LocalizedError {
    case iCloudNotAvailable
    case noBackupFound
    case syncFailed

    var errorDescription: String? {
        switch self {
        case .iCloudNotAvailable:
            return "iCloud is not available. Please sign in to iCloud in System Settings."
        case .noBackupFound:
            return "No backup found in iCloud."
        case .syncFailed:
            return "Sync failed. Please try again."
        }
    }
}
