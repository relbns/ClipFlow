import CoreData
import Foundation

class CoreDataStack {
    static let shared = CoreDataStack()

    lazy var persistentContainer: NSPersistentContainer = {
        // Find the model file in the bundle
        // SPM copies .xcdatamodeld directory, not compiled .momd
        let bundles = [Bundle.module, Bundle.main]
        var managedObjectModel: NSManagedObjectModel?

        for bundle in bundles {
            // Try compiled versions first (.momd, .mom)
            if let url = bundle.url(forResource: "ClipFlow", withExtension: "momd"),
               let model = NSManagedObjectModel(contentsOf: url) {
                managedObjectModel = model
                print("📦 Loaded compiled model (.momd)")
                break
            } else if let url = bundle.url(forResource: "ClipFlow", withExtension: "mom"),
                      let model = NSManagedObjectModel(contentsOf: url) {
                managedObjectModel = model
                print("📦 Loaded compiled model (.mom)")
                break
            }
            // Try source .xcdatamodeld directory (SPM with swift run)
            else if let xcdatamodeldURL = bundle.url(forResource: "ClipFlow", withExtension: "xcdatamodeld") {
                // Use mergedModel to load uncompiled model directory
                if let model = NSManagedObjectModel.mergedModel(from: [bundle]) {
                    managedObjectModel = model
                    print("📦 Loaded source model using mergedModel from \(bundle.bundleIdentifier ?? "bundle")")
                    break
                }
            }
        }

        guard let managedObjectModel = managedObjectModel else {
            fatalError("Unable to load ClipFlow Core Data model from any bundle")
        }

        let container = NSPersistentContainer(name: "ClipFlow", managedObjectModel: managedObjectModel)

        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        return container
    }()

    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    func save() {
        let context = viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("❌ Core Data save error: \(error)")
            }
        }
    }
}
