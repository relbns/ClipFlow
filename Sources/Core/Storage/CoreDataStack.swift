import CoreData
import Foundation

final class CoreDataStack {
    static let shared = CoreDataStack(storeURL: CoreDataStack.defaultStoreURL)

    let persistentContainer: NSPersistentContainer

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

        let description: NSPersistentStoreDescription
        if let storeURL {
            try? FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            StoreMigrator.migrateIfNeeded(storeURL: storeURL, to: model)
            description = NSPersistentStoreDescription(url: storeURL)
        } else {
            description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
        }
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        persistentContainer.persistentStoreDescriptions = [description]

        var loadError: Error?
        persistentContainer.loadPersistentStores { _, error in loadError = error }

        if let loadError, let storeURL {
            Log.storage.error("Could not open the store, starting a fresh one: \(loadError.localizedDescription, privacy: .public)")
            StoreMigrator.moveAside(storeURL: storeURL, suffix: "unreadable")
            persistentContainer.loadPersistentStores { _, error in
                if let error {
                    Log.storage.fault("Could not create a fresh store: \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        viewContext.automaticallyMergesChangesFromParent = true
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

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
        SnippetLibraryRepair.mergeDuplicates(in: viewContext)

        let groupCount = (try? viewContext.count(for: SnippetGroup.fetchRequest())) ?? 0
        let snippetCount = (try? viewContext.count(for: Snippet.fetchRequest())) ?? 0
        guard groupCount == 0, snippetCount == 0, !defaults.bool(forKey: "hasCreatedDefaultSnippets") else { return }

        let group = SnippetGroup(context: viewContext)
        group.id = UUID()
        group.name = "Personal"
        group.isEnabled = true
        group.createdAt = Date()
        group.sortOrder = 0

        let starters: [(title: String, abbreviation: String, content: String)] = [
            ("Today's Date", ".dd", "{date:EEEE, MMM d}"),
            ("Current Time", ".time", "{time:HH:mm}"),
            ("Date and Time", ".now", "{date:EEEE, MMM d} at {time:HH:mm}"),
            ("Email Signature", ".sig", "Best regards,\n{cursor}")
        ]
        for starter in starters {
            let snippet = Snippet(context: viewContext)
            snippet.id = UUID()
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
    /// Migrates a store written by an earlier in-code model. Core Data cannot infer the source
    /// model on its own here, because there is no compiled model bundle to look it up in.
    static func migrateIfNeeded(storeURL: URL, to current: NSManagedObjectModel) {
        guard FileManager.default.fileExists(atPath: storeURL.path),
              let metadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: storeURL),
              !current.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) else { return }

        let source = NSManagedObjectModel.clipFlowModel(version: 1, bindClasses: false)
        guard source.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) else {
            Log.storage.error("Store does not match any known model version")
            return
        }

        let destination = NSManagedObjectModel.clipFlowModel(version: 2, bindClasses: false)
        let temporaryURL = storeURL.deletingLastPathComponent().appendingPathComponent("ClipFlow-migrating.sqlite")
        do {
            copyStore(from: storeURL, to: storeURL.deletingLastPathComponent().appendingPathComponent("ClipFlow-v1-backup.sqlite"))
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
            Log.storage.info("Migrated the store from model v1 to v2")
        } catch {
            Log.storage.error("Store migration failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func moveAside(storeURL: URL, suffix: String) {
        let stamp = Int(Date().timeIntervalSince1970)
        for extensionSuffix in ["", "-wal", "-shm"] {
            let file = URL(fileURLWithPath: storeURL.path + extensionSuffix)
            let target = URL(fileURLWithPath: storeURL.deletingPathExtension().path + "-\(suffix)-\(stamp).sqlite" + extensionSuffix)
            try? FileManager.default.moveItem(at: file, to: target)
        }
    }

    private static func copyStore(from source: URL, to destination: URL) {
        for extensionSuffix in ["", "-wal", "-shm"] {
            let from = URL(fileURLWithPath: source.path + extensionSuffix)
            let to = URL(fileURLWithPath: destination.path + extensionSuffix)
            try? FileManager.default.removeItem(at: to)
            try? FileManager.default.copyItem(at: from, to: to)
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

enum SnippetLibraryRepair {
    /// Folds groups that share a name into the oldest one, then removes snippets that are exact copies.
    static func mergeDuplicates(in context: NSManagedObjectContext) {
        let request = SnippetGroup.fetchRequest()
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
