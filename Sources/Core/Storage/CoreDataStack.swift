import CoreData
import Foundation

class CoreDataStack {
    static let shared = CoreDataStack()

    lazy var persistentContainer: NSPersistentContainer = {
        // Find the model file in the bundle
        // SPM copies .xcdatamodeld directory, not compiled .momd
        let bundles = [Bundle.module, Bundle.main]
        var modelURL: URL?

        for bundle in bundles {
            // Try compiled versions first (.momd, .mom)
            if let url = bundle.url(forResource: "ClipFlow", withExtension: "momd") {
                modelURL = url
                print("📦 Found compiled model (.momd)")
                break
            } else if let url = bundle.url(forResource: "ClipFlow", withExtension: "mom") {
                modelURL = url
                print("📦 Found compiled model (.mom)")
                break
            }
            // Try source .xcdatamodeld directory (SPM with swift run)
            else if let xcdatamodeldURL = bundle.url(forResource: "ClipFlow", withExtension: "xcdatamodeld") {
                // Look for .xcdatamodel inside the directory
                let xcdatamodelURL = xcdatamodeldURL.appendingPathComponent("ClipFlow.xcdatamodel")
                if FileManager.default.fileExists(atPath: xcdatamodelURL.path) {
                    modelURL = xcdatamodelURL
                    print("📦 Found source model (.xcdatamodel in .xcdatamodeld)")
                    break
                }
            }
        }

        guard let modelURL = modelURL else {
            fatalError("Unable to find ClipFlow Core Data model in any bundle")
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
