import CoreData
import Foundation

final class CoreDataStack {
    static let shared = CoreDataStack(storeURL: CoreDataStack.defaultStoreURL)

    enum LoadIssue: Equatable {
        /// The store was written by a newer ClipFlow. It is left untouched and nothing is saved this session.
        case newerVersion
        /// The store could not be read and was renamed to this file; a fresh store was created.
        case movedAside(URL)
    }

    let persistentContainer: NSPersistentContainer
    private(set) var loadIssue: LoadIssue?

    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    static var defaultStoreURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("ClipFlow", isDirectory: true).appendingPathComponent("ClipFlow.sqlite")
    }

    /// `storeURL == nil` keeps everything in memory.
    init(storeURL: URL?) {
        let model = NSManagedObjectModel.clipFlowCurrent
        persistentContainer = NSPersistentContainer(name: "ClipFlow", managedObjectModel: model)

        let inMemory = NSPersistentStoreDescription()
        inMemory.type = NSInMemoryStoreType

        guard let storeURL else {
            persistentContainer.persistentStoreDescriptions = [inMemory]
            persistentContainer.loadPersistentStores { _, _ in }
            configureViewContext()
            return
        }

        try? FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if StoreMigrator.isFromUnknownVersion(storeURL: storeURL) {
            Log.storage.fault("The store was written by a newer ClipFlow; it is left untouched")
            loadIssue = .newerVersion
            persistentContainer.persistentStoreDescriptions = [inMemory]
            persistentContainer.loadPersistentStores { _, _ in }
            configureViewContext()
            return
        }

        StoreMigrator.migrateIfNeeded(storeURL: storeURL, to: model)
        let onDisk = NSPersistentStoreDescription(url: storeURL)
        onDisk.shouldMigrateStoreAutomatically = false
        onDisk.shouldInferMappingModelAutomatically = false
        persistentContainer.persistentStoreDescriptions = [onDisk]

        var loadError: Error?
        persistentContainer.loadPersistentStores { _, error in loadError = error }

        if let loadError {
            Log.storage.error("Could not open the store, starting a fresh one: \(loadError.localizedDescription, privacy: .public)")
            loadIssue = StoreMigrator.moveAside(storeURL: storeURL, suffix: "unreadable").map(LoadIssue.movedAside)
            persistentContainer.loadPersistentStores { _, error in
                if let error {
                    Log.storage.fault("Could not create a fresh store: \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        configureViewContext()
    }

    private func configureViewContext() {
        viewContext.automaticallyMergesChangesFromParent = true
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    /// A context of its own for background services, so their saves never commit the editor's unsaved edits.
    func makeServiceContext() -> NSManagedObjectContext {
        let mainContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        mainContext.persistentStoreCoordinator = persistentContainer.persistentStoreCoordinator
        mainContext.automaticallyMergesChangesFromParent = true
        mainContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return mainContext
    }

    /// Counts a use of a snippet in its own context.
    func recordSnippetUse(_ objectID: NSManagedObjectID) {
        let context = statsContext
        guard let snippet = try? context.existingObject(with: objectID) as? Snippet else { return }
        snippet.useCount += 1
        snippet.lastUsed = Date()
        do {
            try context.save()
        } catch {
            Log.storage.error("Could not save snippet statistics: \(error.localizedDescription, privacy: .public)")
            context.rollback()
        }
    }

    /// Saves from here only count uses, which sync ignores.
    nonisolated static let statsContextName = "stats"

    private lazy var statsContext: NSManagedObjectContext = {
        let context = makeServiceContext()
        context.name = Self.statsContextName
        return context
    }()

    func save() {
        guard viewContext.hasChanges else { return }
        do {
            try viewContext.save()
        } catch {
            Log.storage.error("Save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Default data

    /// Seeds the starter snippets only into an empty store, so no launch path can add them twice.
    func prepareDefaultData(defaults: UserDefaults = .standard) {
        guard loadIssue != .newerVersion else { return }
        if !defaults.bool(forKey: "hasRepairedStarterDuplicates") {
            SnippetLibraryRepair.mergeDuplicates(in: viewContext)
            defaults.set(true, forKey: "hasRepairedStarterDuplicates")
        }

        let groupCount = (try? viewContext.count(for: SnippetGroup.fetchRequest())) ?? 0
        let snippetCount = (try? viewContext.count(for: Snippet.fetchRequest())) ?? 0
        guard groupCount == 0, snippetCount == 0, !defaults.bool(forKey: "hasCreatedDefaultSnippets") else { return }

        let group = SnippetGroup(context: viewContext)
        group.id = StarterSnippets.groupID
        group.name = SnippetLibraryRepair.starterGroupName
        group.isEnabled = true
        group.createdAt = Date()
        group.sortOrder = 0

        for starter in StarterSnippets.all {
            let snippet = Snippet(context: viewContext)
            snippet.id = starter.id
            snippet.title = starter.title
            snippet.abbreviation = starter.abbreviation
            snippet.content = starter.content
            snippet.isEnabled = true
            snippet.createdAt = Date()
            snippet.updatedAt = Date()
            snippet.expandTrigger = ExpandTrigger.delimiter.rawValue
            snippet.group = group
        }

        save()
        defaults.set(true, forKey: "hasCreatedDefaultSnippets")
        Log.storage.info("Created the starter snippets")
    }
}

enum StoreMigrator {
    /// Migrates a store written by an earlier in-code model straight to the current one. Core Data cannot
    /// infer the source model on its own here, because there is no compiled model bundle to look it up in.
    static func migrateIfNeeded(storeURL: URL, to current: NSManagedObjectModel) {
        guard FileManager.default.fileExists(atPath: storeURL.path),
              let metadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: storeURL),
              !current.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) else { return }

        guard let sourceVersion = NSManagedObjectModel.knownVersions.dropLast().first(where: { version in
            NSManagedObjectModel.clipFlowModel(version: version, bindClasses: false)
                .isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        }) else {
            Log.storage.error("Store does not match any known model version")
            return
        }

        let source = NSManagedObjectModel.clipFlowModel(version: sourceVersion, bindClasses: false)
        let destination = NSManagedObjectModel.clipFlowModel(version: NSManagedObjectModel.currentVersion, bindClasses: false)
        let temporaryURL = storeURL.deletingLastPathComponent().appendingPathComponent("ClipFlow-migrating.sqlite")
        do {
            copyStore(from: storeURL, to: storeURL.deletingLastPathComponent().appendingPathComponent("ClipFlow-v\(sourceVersion)-backup.sqlite"))
            destroyStore(at: temporaryURL, model: destination)

            let mapping = try NSMappingModel.inferredMappingModel(forSourceModel: source, destinationModel: destination)
            let manager = NSMigrationManager(sourceModel: source, destinationModel: destination)
            try manager.migrateStore(
                from: storeURL, sourceType: NSSQLiteStoreType, options: nil,
                with: mapping,
                toDestinationURL: temporaryURL, destinationType: NSSQLiteStoreType, destinationOptions: nil
            )

            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: destination)
            try coordinator.replacePersistentStore(
                at: storeURL, destinationOptions: nil,
                withPersistentStoreFrom: temporaryURL, sourceOptions: nil,
                ofType: NSSQLiteStoreType
            )
            destroyStore(at: temporaryURL, model: destination)
            Log.storage.info("Migrated the store from model v\(sourceVersion) to v\(NSManagedObjectModel.currentVersion)")
        } catch {
            Log.storage.error("Store migration failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// True when the store has readable metadata that matches no model this build knows.
    static func isFromUnknownVersion(storeURL: URL) -> Bool {
        guard let metadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: storeURL) else {
            return false
        }
        return !NSManagedObjectModel.knownVersions.contains { version in
            NSManagedObjectModel.clipFlowModel(version: version, bindClasses: false)
                .isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        }
    }

    /// Returns the new location of the main store file.
    @discardableResult
    static func moveAside(storeURL: URL, suffix: String) -> URL? {
        let stamp = Int(Date().timeIntervalSince1970)
        let movedStore = URL(fileURLWithPath: storeURL.deletingPathExtension().path + "-\(suffix)-\(stamp).sqlite")
        for extensionSuffix in ["", "-wal", "-shm"] {
            let file = URL(fileURLWithPath: storeURL.path + extensionSuffix)
            let target = URL(fileURLWithPath: movedStore.path + extensionSuffix)
            try? FileManager.default.moveItem(at: file, to: target)
        }
        try? FileManager.default.moveItem(at: externalDataFolder(of: storeURL), to: externalDataFolder(of: movedStore))
        return FileManager.default.fileExists(atPath: movedStore.path) ? movedStore : nil
    }

    /// Where Core Data keeps attributes stored outside the SQLite file.
    static func externalDataFolder(of storeURL: URL) -> URL {
        let name = storeURL.deletingPathExtension().lastPathComponent
        return storeURL.deletingLastPathComponent().appendingPathComponent(".\(name)_SUPPORT", isDirectory: true)
    }

    private static func copyStore(from source: URL, to destination: URL) {
        for extensionSuffix in ["", "-wal", "-shm"] {
            let from = URL(fileURLWithPath: source.path + extensionSuffix)
            let to = URL(fileURLWithPath: destination.path + extensionSuffix)
            try? FileManager.default.removeItem(at: to)
            try? FileManager.default.copyItem(at: from, to: to)
        }
        let supportFrom = externalDataFolder(of: source)
        let supportTo = externalDataFolder(of: destination)
        try? FileManager.default.removeItem(at: supportTo)
        if FileManager.default.fileExists(atPath: supportFrom.path) {
            try? FileManager.default.copyItem(at: supportFrom, to: supportTo)
        }
    }

    private static func destroyStore(at url: URL, model: NSManagedObjectModel) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try? coordinator.destroyPersistentStore(at: url, ofType: NSSQLiteStoreType, options: nil)
        for extensionSuffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + extensionSuffix))
        }
    }
}

/// The snippets every Mac starts with. Their ids are fixed, so on Macs that sync they are the same snippets,
/// not copies to reconcile.
enum StarterSnippets {
    struct Starter {
        let id: UUID
        let title: String
        let abbreviation: String
        let content: String
    }

    static let groupID = UUID(uuidString: "C1F10A00-0000-4000-8000-000000000001")!
    static let all = [
        Starter(id: UUID(uuidString: "C1F10A00-0000-4000-8000-000000000011")!, title: "Today's Date", abbreviation: ".dd",
                content: "{date:EEEE, MMM d}"),
        Starter(id: UUID(uuidString: "C1F10A00-0000-4000-8000-000000000012")!, title: "Current Time", abbreviation: ".time",
                content: "{time:HH:mm}"),
        Starter(id: UUID(uuidString: "C1F10A00-0000-4000-8000-000000000013")!, title: "Date and Time", abbreviation: ".now",
                content: "{date:EEEE, MMM d} at {time:HH:mm}"),
        Starter(id: UUID(uuidString: "C1F10A00-0000-4000-8000-000000000014")!, title: "Email Signature", abbreviation: ".sig",
                content: "Best regards,\n{cursor}")
    ]

    /// Installs from before the fixed ids created the starters with random ones. Before a Mac first syncs, each
    /// starter it still has exactly as created (title, abbreviation and text) takes the fixed id, and the starter
    /// group the fixed group id, so they meet the other Macs' starters as the same snippets. Changed or missing
    /// starters keep their ids. Returns whether anything changed.
    @discardableResult
    static func adoptFixedIDs(in context: NSManagedObjectContext) -> Bool {
        let snippets = (try? context.fetch(Snippet.fetchRequest())) ?? []
        let groups = (try? context.fetch(SnippetGroup.fetchRequest())) ?? []
        let takenSnippetIDs = Set(snippets.map(\.id))
        var changed = false
        for starter in all where !takenSnippetIDs.contains(starter.id) {
            guard let snippet = snippets.first(where: {
                $0.title == starter.title && $0.abbreviation == starter.abbreviation && $0.content == starter.content
            }) else { continue }
            snippet.id = starter.id
            changed = true
        }
        if !groups.contains(where: { $0.id == groupID }),
           let group = groups.first(where: { $0.name == SnippetLibraryRepair.starterGroupName && $0.snippets.contains { s in all.contains { $0.id == s.id } } }) {
            group.id = groupID
            changed = true
        }
        return changed
    }
}

enum SnippetLibraryRepair {
    static let starterGroupName = "Personal"

    /// Earlier builds could seed the starter group more than once. Folds those copies into the oldest
    /// one and removes exact duplicate snippets inside it. Groups the user created are never touched.
    static func mergeDuplicates(in context: NSManagedObjectContext) {
        let request = SnippetGroup.fetchRequest()
        request.predicate = NSPredicate(format: "name ==[c] %@", starterGroupName)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        guard let groups = try? context.fetch(request) else { return }

        var keeperByName: [String: SnippetGroup] = [:]
        var changed = false
        for group in groups {
            let key = group.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard let keeper = keeperByName[key] else {
                keeperByName[key] = group
                continue
            }
            for snippet in group.snippets { snippet.group = keeper }
            context.delete(group)
            changed = true
        }

        for keeper in keeperByName.values {
            var seen: [String: Snippet] = [:]
            for snippet in keeper.snippets.sorted(by: { $0.createdAt < $1.createdAt }) {
                let key = [snippet.title, snippet.abbreviation, snippet.content].joined(separator: "\u{1F}")
                if let original = seen[key] {
                    original.useCount += snippet.useCount
                    if let used = snippet.lastUsed, used > (original.lastUsed ?? .distantPast) { original.lastUsed = used }
                    context.delete(snippet)
                    changed = true
                } else {
                    seen[key] = snippet
                }
            }
        }

        guard changed else { return }
        do {
            try context.save()
            Log.storage.info("Merged duplicate snippet groups and snippets")
        } catch {
            Log.storage.error("Could not merge duplicates: \(error.localizedDescription, privacy: .public)")
        }
    }
}
