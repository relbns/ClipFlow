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
            "ocrSaveScreenshots": true,
            "syncEnabled": false,
            "syncSettings": true,
            "syncPins": true,
            "ocrIndexImages": true,
            "excludedApps": "[]",
            SensitiveText.handlingKey: SensitiveHandling.expire.rawValue,
            SensitiveText.minutesKey: 5,
            SensitiveText.clearClipboardKey: false,
            SensitiveKind.oneTimeCode.defaultsKey: true,
            SensitiveKind.cardNumber.defaultsKey: true,
            SensitiveKind.iban.defaultsKey: true
        ])
    }
}
