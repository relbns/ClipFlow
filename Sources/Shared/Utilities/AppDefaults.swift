import Foundation

/// Registered once at launch, so services read the same defaults the Preferences screens show.
enum AppDefaults {
    static func register(in defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            "maxHistoryItems": 30.0,
            "removeDuplicates": true,
            "moveUsedToTop": true,
            "startMonitoring": true,
            "textExpansionEnabled": true,
            "expandAfter": "delimiter",
            "playSoundOnExpand": false,
            "viewMode": "organized",
            "appearanceMode": "auto",
            "closePopoverOnOutsideClick": true,
            "layoutFixSwitchesKeyboard": true,
            "alwaysPastePlainText": false,
            "excludedApps": "[]"
        ])
    }
}
