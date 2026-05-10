import CoreData

/// Programmatically create the Core Data model
/// This works in both Xcode and swift run without needing compiled .momd files
extension NSManagedObjectModel {
    static func clipFlowModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // MARK: - ClipItem Entity
        let clipItemEntity = NSEntityDescription()
        clipItemEntity.name = "ClipItem"
        clipItemEntity.managedObjectClassName = "ClipItem"

        var clipItemProperties: [NSPropertyDescription] = []

        // id: UUID
        let clipItemId = NSAttributeDescription()
        clipItemId.name = "id"
        clipItemId.attributeType = .UUIDAttributeType
        clipItemId.isOptional = false
        clipItemProperties.append(clipItemId)

        // content: String
        let clipItemContent = NSAttributeDescription()
        clipItemContent.name = "content"
        clipItemContent.attributeType = .stringAttributeType
        clipItemContent.isOptional = false
        clipItemContent.defaultValue = ""
        clipItemProperties.append(clipItemContent)

        // type: String
        let clipItemType = NSAttributeDescription()
        clipItemType.name = "type"
        clipItemType.attributeType = .stringAttributeType
        clipItemType.isOptional = false
        clipItemContent.defaultValue = "text"
        clipItemProperties.append(clipItemType)

        // createdAt: Date
        let clipItemCreatedAt = NSAttributeDescription()
        clipItemCreatedAt.name = "createdAt"
        clipItemCreatedAt.attributeType = .dateAttributeType
        clipItemCreatedAt.isOptional = false
        clipItemProperties.append(clipItemCreatedAt)

        // dataHash: String
        let clipItemHash = NSAttributeDescription()
        clipItemHash.name = "dataHash"
        clipItemHash.attributeType = .stringAttributeType
        clipItemHash.isOptional = false
        clipItemProperties.append(clipItemHash)

        // isPinned: Bool
        let clipItemPinned = NSAttributeDescription()
        clipItemPinned.name = "isPinned"
        clipItemPinned.attributeType = .booleanAttributeType
        clipItemPinned.defaultValue = false
        clipItemProperties.append(clipItemPinned)

        // imageData: Data?
        let clipItemImageData = NSAttributeDescription()
        clipItemImageData.name = "imageData"
        clipItemImageData.attributeType = .binaryDataAttributeType
        clipItemImageData.isOptional = true
        clipItemProperties.append(clipItemImageData)

        // rtfData: Data?
        let clipItemRtfData = NSAttributeDescription()
        clipItemRtfData.name = "rtfData"
        clipItemRtfData.attributeType = .binaryDataAttributeType
        clipItemRtfData.isOptional = true
        clipItemProperties.append(clipItemRtfData)

        // fileURLs: [String]?
        let clipItemFileURLs = NSAttributeDescription()
        clipItemFileURLs.name = "fileURLs"
        clipItemFileURLs.attributeType = .transformableAttributeType
        clipItemFileURLs.valueTransformerName = "NSSecureUnarchiveFromData"
        clipItemFileURLs.isOptional = true
        clipItemProperties.append(clipItemFileURLs)

        clipItemEntity.properties = clipItemProperties

        // MARK: - Snippet Entity
        let snippetEntity = NSEntityDescription()
        snippetEntity.name = "Snippet"
        snippetEntity.managedObjectClassName = "Snippet"

        var snippetProperties: [NSPropertyDescription] = []

        // id: UUID
        let snippetId = NSAttributeDescription()
        snippetId.name = "id"
        snippetId.attributeType = .UUIDAttributeType
        snippetId.isOptional = false
        snippetProperties.append(snippetId)

        // Basic attributes
        let snippetTitle = createStringAttribute(name: "title", defaultValue: "")
        snippetProperties.append(snippetTitle)

        let snippetAbbr = createStringAttribute(name: "abbreviation", defaultValue: "")
        snippetProperties.append(snippetAbbr)

        let snippetContent = createStringAttribute(name: "content", defaultValue: "")
        snippetProperties.append(snippetContent)

        let snippetEnabled = createBoolAttribute(name: "isEnabled", defaultValue: true)
        snippetProperties.append(snippetEnabled)

        let snippetCreated = createDateAttribute(name: "createdAt")
        snippetProperties.append(snippetCreated)

        let snippetUpdated = createDateAttribute(name: "updatedAt")
        snippetProperties.append(snippetUpdated)

        // Expansion settings
        let snippetTrigger = createStringAttribute(name: "expandTrigger", defaultValue: "delimiter")
        snippetProperties.append(snippetTrigger)

        let snippetCaseSensitive = createBoolAttribute(name: "caseSensitive", defaultValue: false)
        snippetProperties.append(snippetCaseSensitive)

        let snippetPlaySound = createBoolAttribute(name: "playSound", defaultValue: false)
        snippetProperties.append(snippetPlaySound)

        let snippetRestrictApps = createBoolAttribute(name: "restrictToApps", defaultValue: false)
        snippetProperties.append(snippetRestrictApps)

        // Statistics
        let snippetUseCount = createIntAttribute(name: "useCount", defaultValue: 0)
        snippetProperties.append(snippetUseCount)

        let snippetLastUsed = NSAttributeDescription()
        snippetLastUsed.name = "lastUsed"
        snippetLastUsed.attributeType = .dateAttributeType
        snippetLastUsed.isOptional = true
        snippetProperties.append(snippetLastUsed)

        snippetEntity.properties = snippetProperties

        // MARK: - SnippetGroup Entity
        let groupEntity = NSEntityDescription()
        groupEntity.name = "SnippetGroup"
        groupEntity.managedObjectClassName = "SnippetGroup"

        var groupProperties: [NSPropertyDescription] = []

        let groupId = NSAttributeDescription()
        groupId.name = "id"
        groupId.attributeType = .UUIDAttributeType
        groupId.isOptional = false
        groupProperties.append(groupId)

        let groupName = createStringAttribute(name: "name", defaultValue: "")
        groupProperties.append(groupName)

        let groupEnabled = createBoolAttribute(name: "isEnabled", defaultValue: true)
        groupProperties.append(groupEnabled)

        let groupCreated = createDateAttribute(name: "createdAt")
        groupProperties.append(groupCreated)

        let groupSortOrder = createIntAttribute(name: "sortOrder", defaultValue: 0)
        groupProperties.append(groupSortOrder)

        groupEntity.properties = groupProperties

        // MARK: - AppRule Entity
        let appRuleEntity = NSEntityDescription()
        appRuleEntity.name = "AppRule"
        appRuleEntity.managedObjectClassName = "AppRule"

        var appRuleProperties: [NSPropertyDescription] = []

        let appRuleId = NSAttributeDescription()
        appRuleId.name = "id"
        appRuleId.attributeType = .UUIDAttributeType
        appRuleId.isOptional = false
        appRuleProperties.append(appRuleId)

        let appRuleBundleId = createStringAttribute(name: "bundleIdentifier", defaultValue: "")
        appRuleProperties.append(appRuleBundleId)

        let appRuleName = createStringAttribute(name: "appName", defaultValue: "")
        appRuleProperties.append(appRuleName)

        appRuleEntity.properties = appRuleProperties

        // MARK: - Relationships

        // Snippet → Group (many-to-one)
        let snippetToGroup = NSRelationshipDescription()
        snippetToGroup.name = "group"
        snippetToGroup.destinationEntity = groupEntity
        snippetToGroup.minCount = 0
        snippetToGroup.maxCount = 1
        snippetToGroup.deleteRule = .nullifyDeleteRule

        // Group → Snippets (one-to-many)
        let groupToSnippets = NSRelationshipDescription()
        groupToSnippets.name = "snippets"
        groupToSnippets.destinationEntity = snippetEntity
        groupToSnippets.minCount = 0
        groupToSnippets.maxCount = 0 // 0 means unlimited
        groupToSnippets.deleteRule = .cascadeDeleteRule

        snippetToGroup.inverseRelationship = groupToSnippets
        groupToSnippets.inverseRelationship = snippetToGroup

        snippetEntity.properties.append(snippetToGroup)
        groupEntity.properties.append(groupToSnippets)

        // Snippet → AppRules (one-to-many)
        let snippetToAppRules = NSRelationshipDescription()
        snippetToAppRules.name = "appRules"
        snippetToAppRules.destinationEntity = appRuleEntity
        snippetToAppRules.minCount = 0
        snippetToAppRules.maxCount = 0
        snippetToAppRules.deleteRule = .cascadeDeleteRule

        // AppRule → Snippet (many-to-one)
        let appRuleToSnippet = NSRelationshipDescription()
        appRuleToSnippet.name = "snippet"
        appRuleToSnippet.destinationEntity = snippetEntity
        appRuleToSnippet.minCount = 0
        appRuleToSnippet.maxCount = 1
        appRuleToSnippet.deleteRule = .nullifyDeleteRule

        snippetToAppRules.inverseRelationship = appRuleToSnippet
        appRuleToSnippet.inverseRelationship = snippetToAppRules

        snippetEntity.properties.append(snippetToAppRules)
        appRuleEntity.properties.append(appRuleToSnippet)

        // Add entities to model
        model.entities = [clipItemEntity, snippetEntity, groupEntity, appRuleEntity]

        return model
    }

    // Helper functions
    private static func createStringAttribute(name: String, defaultValue: String) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .stringAttributeType
        attr.isOptional = false
        attr.defaultValue = defaultValue
        return attr
    }

    private static func createBoolAttribute(name: String, defaultValue: Bool) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .booleanAttributeType
        attr.isOptional = false
        attr.defaultValue = defaultValue
        return attr
    }

    private static func createIntAttribute(name: String, defaultValue: Int) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .integer32AttributeType
        attr.isOptional = false
        attr.defaultValue = defaultValue
        return attr
    }

    private static func createDateAttribute(name: String) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .dateAttributeType
        attr.isOptional = false
        return attr
    }
}
