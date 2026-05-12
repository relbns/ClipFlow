import CoreData
import Foundation

class CoreDataStack {
    static let shared = CoreDataStack()

    lazy var persistentContainer: NSPersistentContainer = {
        // Use programmatic model (works in both Xcode and swift run)
        let managedObjectModel = NSManagedObjectModel.clipFlowModel()
        print("📦 Using programmatic Core Data model")

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

    // MARK: - Default Data

    func createDefaultSnippetsIfNeeded() {
        let hasCreatedDefaults = UserDefaults.standard.bool(forKey: "hasCreatedDefaultSnippets")
        if hasCreatedDefaults {
            print("✅ Default snippets already exist")
            return
        }

        print("🎯 Creating default snippets...")

        let context = viewContext

        // Create default group
        let defaultGroup = SnippetGroup(context: context)
        defaultGroup.id = UUID()
        defaultGroup.name = "Personal"
        defaultGroup.isEnabled = true
        defaultGroup.createdAt = Date()
        defaultGroup.sortOrder = 0

        // Helper to create snippet
        func createSnippet(
            title: String,
            abbreviation: String,
            content: String,
            group: SnippetGroup
        ) {
            let snippet = Snippet(context: context)
            snippet.id = UUID()
            snippet.title = title
            snippet.abbreviation = abbreviation
            snippet.content = content
            snippet.isEnabled = true
            snippet.createdAt = Date()
            snippet.updatedAt = Date()
            snippet.expandTrigger = ExpandTrigger.delimiter.rawValue
            snippet.caseSensitive = false
            snippet.playSound = false
            snippet.restrictToApps = false
            snippet.useCount = 0
            snippet.group = group
        }

        // Create default snippets
        createSnippet(
            title: "Today's Date",
            abbreviation: ".dd",
            content: "{date:EEEE, MMM d}",
            group: defaultGroup
        )

        createSnippet(
            title: "Current Time",
            abbreviation: ".time",
            content: "{date:HH:mm}",
            group: defaultGroup
        )

        createSnippet(
            title: "Date and Time",
            abbreviation: ".now",
            content: "{date:EEEE, MMM d} at {date:HH:mm}",
            group: defaultGroup
        )

        createSnippet(
            title: "Email Signature",
            abbreviation: ".sig",
            content: """
            Best,
            {clipboard}
            """,
            group: defaultGroup
        )

        // Save
        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: "hasCreatedDefaultSnippets")
            print("✅ Default snippets created successfully")
        } catch {
            print("❌ Failed to create default snippets: \(error)")
        }
    }
}
