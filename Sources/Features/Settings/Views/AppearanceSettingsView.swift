import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("appearanceMode") private var appearanceMode = "auto"
    @AppStorage("viewMode") private var viewMode = "organized"
    @AppStorage("closePopoverOnOutsideClick") private var closeOnOutsideClick = true

    private let themes = ["auto", "light", "dark"]
    private let modes = ["simple", "organized"]

    var body: some View {
        SettingsPage {
            CFSettingsRow(label: L("pref_theme"), hint: L("pref_theme_hint")) {
                CFSegmentedControl(
                    selection: Binding(
                        get: { themes.firstIndex(of: appearanceMode) ?? 0 },
                        set: { appearanceMode = themes[$0] }
                    ),
                    options: [L("theme_system"), L("theme_light"), L("theme_dark")]
                )
                .frame(maxWidth: 320)
            }
            CFSettingsRow(label: L("pref_close_outside"), hint: L("pref_close_outside_hint")) {
                CFToggle(isOn: $closeOnOutsideClick).accessibilityLabel(L("pref_close_outside"))
            }
            CFSettingsRow(label: L("pref_view_mode"), hint: L("pref_view_mode_hint"), isLast: true) {
                CFSegmentedControl(
                    selection: Binding(
                        get: { modes.firstIndex(of: viewMode) ?? 1 },
                        set: { viewMode = modes[$0] }
                    ),
                    options: [L("mode_simple"), L("mode_organized")]
                )
                .frame(maxWidth: 240)
            }
        }
    }
}
