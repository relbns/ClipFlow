import AppKit

struct ExcludedApp: Codable, Identifiable, Equatable {
    var id: String { bundleID }
    let bundleID: String
    let name: String
    var excludeFromHistory: Bool
    var excludeFromExpansion: Bool

    enum Scope {
        case history
        case expansion
    }

    private enum CodingKeys: String, CodingKey {
        case bundleID, name, excludeFromHistory, excludeFromExpansion
    }

    func isExcluded(from scope: Scope) -> Bool {
        scope == .history ? excludeFromHistory : excludeFromExpansion
    }
}

extension Array where Element == ExcludedApp {
    /// Adds the app to one scope, keeping a single entry per app.
    func adding(bundleID: String, name: String, to scope: ExcludedApp.Scope) -> [ExcludedApp] {
        var result = self
        if let index = result.firstIndex(where: { $0.bundleID == bundleID }) {
            if scope == .history { result[index].excludeFromHistory = true } else { result[index].excludeFromExpansion = true }
        } else {
            result.append(ExcludedApp(bundleID: bundleID, name: name, excludeFromHistory: scope == .history, excludeFromExpansion: scope == .expansion))
        }
        return result
    }

    /// Removes the app from one scope; the entry goes away once it is in neither.
    func removing(bundleID: String, from scope: ExcludedApp.Scope) -> [ExcludedApp] {
        compactMap { app in
            guard app.bundleID == bundleID else { return app }
            var updated = app
            if scope == .history { updated.excludeFromHistory = false } else { updated.excludeFromExpansion = false }
            return updated.excludeFromHistory || updated.excludeFromExpansion ? updated : nil
        }
    }
}

/// Apps listed in Preferences where history is not recorded or snippets do not expand.
@MainActor
enum AppExclusions {
    static let defaultsKey = "excludedApps"
    private static var cachedJSON: String?
    private static var cachedApps: [ExcludedApp] = []

    static var history: Set<String> {
        Set(apps.filter(\.excludeFromHistory).map(\.bundleID))
    }

    static var expansion: Set<String> {
        Set(apps.filter(\.excludeFromExpansion).map(\.bundleID))
    }

    static var apps: [ExcludedApp] {
        let json = UserDefaults.standard.string(forKey: defaultsKey) ?? "[]"
        if json != cachedJSON {
            cachedJSON = json
            cachedApps = decode(json)
        }
        return cachedApps
    }

    static func decode(_ json: String) -> [ExcludedApp] {
        (try? JSONDecoder().decode([ExcludedApp].self, from: Data(json.utf8))) ?? []
    }

    static func encode(_ apps: [ExcludedApp]) -> String {
        (try? JSONEncoder().encode(apps)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    /// Lets the user choose an application; returns its bundle id and display name.
    static func pickApplication(completion: @escaping (_ bundleID: String, _ name: String) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.begin { response in
            guard response == .OK, let url = panel.url, let bundle = Bundle(url: url),
                  let bundleID = bundle.bundleIdentifier else { return }
            let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
            completion(bundleID, name)
        }
    }
}
