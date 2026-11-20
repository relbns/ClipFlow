import KeyboardShortcuts
import SwiftUI

struct ImageTextSettingsView: View {
    @AppStorage(ScreenTextCapture.saveScreenshotsKey) private var saveScreenshots = true
    @AppStorage(ImageTextIndexer.enabledKey) private var indexImages = true
    @AppStorage(TextRecognizer.languagesKey) private var savedLanguages = ""
    @State private var hasScreenAccess = CGPreflightScreenCaptureAccess()
    @Environment(\.cfTheme) private var theme

    private let supported = TextRecognizer.supportedLanguages()

    private var selected: [String] {
        TextRecognizer.languages(
            saved: savedLanguages.split(separator: ",").map(String.init),
            preferred: Locale.preferredLanguages,
            supported: supported
        )
    }

    var body: some View {
        SettingsPage {
            CFSettingsRow(label: L("hotkey_capture_text"), hint: L("hotkey_capture_text_hint")) {
                KeyboardShortcuts.Recorder(for: .captureScreenText)
            }
            CFSettingsRow(label: L("ocr_screen_access"), hint: L("ocr_screen_access_hint")) {
                if hasScreenAccess {
                    Text(L("ocr_screen_access_granted")).font(.system(size: 12)).foregroundColor(theme.textMid)
                } else {
                    HStack(spacing: 8) {
                        CFToolbarBtn(label: L("ocr_permission_open")) {
                            CGRequestScreenCaptureAccess()
                            ScreenTextCapture.openScreenRecordingSettings()
                        }
                        CFToolbarBtn(label: L("ocr_permission_relaunch")) { ScreenTextCapture.relaunch() }
                    }
                }
            }
            CFSettingsRow(label: L("ocr_save_screenshots"), hint: L("ocr_save_screenshots_hint")) {
                CFToggle(isOn: $saveScreenshots).accessibilityLabel(L("ocr_save_screenshots"))
            }
            CFSettingsRow(label: L("ocr_index_images"), hint: L("ocr_index_images_hint")) {
                CFToggle(isOn: $indexImages).accessibilityLabel(L("ocr_index_images"))
            }
            CFSettingsRow(label: L("ocr_languages"), hint: L("ocr_languages_hint"), isLast: true) {
                Menu(selected.map(Self.displayName).joined(separator: ", ")) {
                    ForEach(supported, id: \.self) { language in
                        Toggle(Self.displayName(language), isOn: binding(for: language))
                    }
                }
                .frame(maxWidth: 260)
                .accessibilityLabel(L("ocr_languages"))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasScreenAccess = CGPreflightScreenCaptureAccess()
        }
    }

    private func binding(for language: String) -> Binding<Bool> {
        Binding(
            get: { selected.contains(language) },
            set: { isOn in
                var languages = selected.filter { $0 != language }
                if isOn { languages.append(language) }
                guard !languages.isEmpty else { return }
                savedLanguages = languages.joined(separator: ",")
            }
        )
    }

    private static func displayName(_ identifier: String) -> String {
        Locale(identifier: LanguageManager.shared.currentLanguage).localizedString(forIdentifier: identifier) ?? identifier
    }
}
