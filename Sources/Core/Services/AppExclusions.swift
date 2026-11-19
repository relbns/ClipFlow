import Foundation

/// Apps listed in Preferences where history is not recorded or snippets do not expand.
@MainActor
enum AppExclusions {
    private static var cachedJSON: String?
    private static var cachedApps: [ExcludedApp] = []

    static var history: Set<String> {
        Set(apps.filter(\.excludeFromHistory).map(\.bundleID))
    }

    static var expansion: Set<String> {
        Set(apps.filter(\.excludeFromExpansion).map(\.bundleID))
    }

    private static var apps: [ExcludedApp] {
        let json = UserDefaults.standard.string(forKey: "excludedApps") ?? "[]"
        if json != cachedJSON {
            cachedJSON = json
            cachedApps = (try? JSONDecoder().decode([ExcludedApp].self, from: Data(json.utf8))) ?? []
        }
        return cachedApps
    }
}
