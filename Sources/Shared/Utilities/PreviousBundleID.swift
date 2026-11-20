import AppKit

/// Moves ClipFlow off the bundle id it had before `io.benesh.clipflow`.
enum PreviousBundleID {
    static let identifier = "com.singalong.clipflow"

    /// Copies the old settings unless the new domain already has its own, then deletes the old domain so they never come back.
    static func migrateDefaultsIfNeeded(
        defaults: UserDefaults = .standard,
        from previous: String = identifier,
        to current: String? = Bundle.main.bundleIdentifier
    ) {
        guard let current, current != previous,
              let old = defaults.persistentDomain(forName: previous), !old.isEmpty else { return }
        if defaults.persistentDomain(forName: current)?.isEmpty ?? true {
            defaults.setPersistentDomain(old, forName: current)
        }
        defaults.removePersistentDomain(forName: previous)
    }

    /// A copy still running under the old id would expand every abbreviation a second time.
    static func quitRunningCopies() {
        NSRunningApplication.runningApplications(withBundleIdentifier: identifier).forEach { $0.terminate() }
    }
}
