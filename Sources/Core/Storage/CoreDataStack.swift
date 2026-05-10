import CoreData
import Foundation

class CoreDataStack {
    static let shared = CoreDataStack()

    lazy var persistentContainer: NSPersistentContainer = {
        // Find the model file in the bundle
        guard let modelURL = Bundle.main.url(forResource: "ClipFlow", withExtension: "momd") else {
            fatalError("Unable to find ClipFlow.momd in bundle")
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
