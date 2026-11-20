import CoreData

/// The model is built in code so it works the same from `swift build` and from Xcode.
/// v1 is the shape stores were created with before v2; it is kept only to migrate them.
extension NSManagedObjectModel {
    static let currentVersion = 4
    static let knownVersions = [1, 2, 3, 4]
    static let clipFlowCurrent = clipFlowModel(version: currentVersion, bindClasses: true)

    static func clipFlowModel(version: Int, bindClasses: Bool) -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        func entity(_ name: String) -> NSEntityDescription {
            let entity = NSEntityDescription()
            entity.name = name
            entity.managedObjectClassName = bindClasses ? name : NSStringFromClass(NSManagedObject.self)
            return entity
        }

        let clipItem = entity("ClipItem")
        var clipProperties: [NSPropertyDescription] = [
            uuid("id"),
            string("content", default: ""),
            string("type", default: "text"),
            date("createdAt"),
            string("dataHash", default: ""),
            attribute("isPinned", .booleanAttributeType, optional: true, default: false),
            binary("imageData", external: false),
            binary("rtfData", external: false),
            transformable("fileURLs")
        ]
        if version >= 2 {
            clipProperties += [
                binary("pasteboardData", external: true),
                optionalString("sourceAppName"),
                optionalString("sourceBundleID"),
                int64("byteCount"),
                int32("pixelWidth"),
                int32("pixelHeight")
            ]
        }
        if version >= 4 {
            clipProperties.append(optionalString("recognizedText"))
        }
        clipItem.properties = clipProperties

        let snippet = entity("Snippet")
        snippet.properties = [
            uuid("id"),
            string("title", default: ""),
            string("abbreviation", default: ""),
            string("content", default: ""),
            bool("isEnabled", default: true),
            date("createdAt"),
            date("updatedAt"),
            string("expandTrigger", default: "delimiter"),
            bool("caseSensitive", default: false),
            bool("playSound", default: false),
            bool("restrictToApps", default: false),
            int32("useCount"),
            optionalDate("lastUsed")
        ]
        if version >= 3 {
            snippet.properties.append(bool("isFavorite", default: false))
        }

        let group = entity("SnippetGroup")
        group.properties = [
            uuid("id"),
            string("name", default: ""),
            bool("isEnabled", default: true),
            date("createdAt"),
            int32("sortOrder"),
            optionalString("syncLocation"),
            optionalString("gistId"),
            optionalDate("lastSynced")
        ]

        let appRule = entity("AppRule")
        var ruleProperties: [NSPropertyDescription] = [
            uuid("id"),
            string("bundleIdentifier", default: ""),
            string("appName", default: "")
        ]
        if version >= 2 {
            ruleProperties += [
                bool("isEnabled", default: true),
                bool("isDeny", default: false)
            ]
        }
        appRule.properties = ruleProperties

        relate(snippet, "group", toOne: group, inverse: "snippets", inverseDelete: .cascadeDeleteRule)
        relate(appRule, "snippet", toOne: snippet, inverse: "appRules", inverseDelete: .cascadeDeleteRule)

        model.entities = [clipItem, snippet, group, appRule]
        return model
    }

    private static func relate(
        _ child: NSEntityDescription,
        _ name: String,
        toOne parent: NSEntityDescription,
        inverse inverseName: String,
        inverseDelete: NSDeleteRule
    ) {
        let toParent = NSRelationshipDescription()
        toParent.name = name
        toParent.destinationEntity = parent
        toParent.minCount = 0
        toParent.maxCount = 1
        toParent.deleteRule = .nullifyDeleteRule

        let toChildren = NSRelationshipDescription()
        toChildren.name = inverseName
        toChildren.destinationEntity = child
        toChildren.minCount = 0
        toChildren.maxCount = 0
        toChildren.deleteRule = inverseDelete

        toParent.inverseRelationship = toChildren
        toChildren.inverseRelationship = toParent
        child.properties.append(toParent)
        parent.properties.append(toChildren)
    }

    private static func attribute(_ name: String, _ type: NSAttributeType, optional: Bool, default value: Any? = nil) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        attribute.defaultValue = value
        return attribute
    }

    private static func uuid(_ name: String) -> NSAttributeDescription { attribute(name, .UUIDAttributeType, optional: false) }
    private static func string(_ name: String, default value: String) -> NSAttributeDescription { attribute(name, .stringAttributeType, optional: false, default: value) }
    private static func optionalString(_ name: String) -> NSAttributeDescription { attribute(name, .stringAttributeType, optional: true) }
    private static func bool(_ name: String, default value: Bool) -> NSAttributeDescription { attribute(name, .booleanAttributeType, optional: false, default: value) }
    private static func int32(_ name: String) -> NSAttributeDescription { attribute(name, .integer32AttributeType, optional: false, default: 0) }
    private static func int64(_ name: String) -> NSAttributeDescription { attribute(name, .integer64AttributeType, optional: false, default: 0) }
    private static func date(_ name: String) -> NSAttributeDescription { attribute(name, .dateAttributeType, optional: false) }
    private static func optionalDate(_ name: String) -> NSAttributeDescription { attribute(name, .dateAttributeType, optional: true) }

    private static func binary(_ name: String, external: Bool) -> NSAttributeDescription {
        let attribute = attribute(name, .binaryDataAttributeType, optional: true)
        attribute.allowsExternalBinaryDataStorage = external
        return attribute
    }

    private static func transformable(_ name: String) -> NSAttributeDescription {
        let attribute = attribute(name, .transformableAttributeType, optional: true)
        attribute.valueTransformerName = NSValueTransformerName.secureUnarchiveFromDataTransformerName.rawValue
        return attribute
    }
}
