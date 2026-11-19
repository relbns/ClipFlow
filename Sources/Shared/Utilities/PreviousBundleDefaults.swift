import Foundation

/// Carries the settings over from the bundle id ClipFlow had before `io.benesh.clipflow`, once.
enum PreviousBundleDefaults {
    static let previousBundleID = "com.singalong.clipflow"

    static func migrateIfNeeded(
        defaults: UserDefaults = .standard,
        from previous: String = previousBundleID,
        to current: String? = Bundle.main.bundleIdentifier
    ) {
        guard let current, current != previous,
              defaults.persistentDomain(forName: current)?.isEmpty ?? true,
              let old = defaults.persistentDomain(forName: previous), !old.isEmpty else { return }
        defaults.setPersistentDomain(old, forName: current)
    }
}
