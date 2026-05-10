import CoreData
import Foundation

class CoreDataStack {
    static let shared = CoreDataStack()

    lazy var persistentContainer: NSPersistentContainer = {
        // Find the model file in the bundle
        // Try module bundle first (for SPM), then main bundle (for built app)
        let bundles = [Bundle.module, Bundle.main]
        var modelURL: URL?

        for bundle in bundles {
            if let url = bundle.url(forResource: "ClipFlow", withExtension: "momd") {
                modelURL = url
                print("📦 Found Core Data model in bundle: \(bundle.bundlePath)")
                break
            }
        }

        guard let modelURL = modelURL else {
            fatalError("Unable to find ClipFlow.momd in any bundle")
        }

        guard let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Unable to load model from \(modelURL)")
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
