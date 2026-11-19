import Foundation
import CoreData

@objc(AppRule)
public class AppRule: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var bundleIdentifier: String
    @NSManaged public var appName: String
    @NSManaged public var isEnabled: Bool
    /// true: never expand in this app. false: an allow rule, used when the snippet is restricted to apps.
    @NSManaged public var isDeny: Bool
    @NSManaged public var snippet: Snippet?

    @nonobjc public class func fetchRequest() -> NSFetchRequest<AppRule> {
        return NSFetchRequest<AppRule>(entityName: "AppRule")
    }
}

extension AppRule {
    static func create(in context: NSManagedObjectContext, bundleID: String, appName: String, isDeny: Bool = false) -> AppRule {
        let rule = AppRule(context: context)
        rule.id = UUID()
        rule.bundleIdentifier = bundleID
        rule.appName = appName
        rule.isEnabled = true
        rule.isDeny = isDeny
        return rule
    }
}
