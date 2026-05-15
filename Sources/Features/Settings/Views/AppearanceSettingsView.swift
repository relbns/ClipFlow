import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("appearanceMode") private var appearanceMode = "auto"
    @AppStorage("viewMode") private var viewMode = "organized"
    @AppStorage("showIcons") private var showIcons = true
    @AppStorage("showThumbnails") private var showThumbnails = true
    @AppStorage("menuItemsNumbered") private var menuItemsNumbered = true
    @AppStorage("maxTitleLength") private var maxTitleLength = 50.0

    @Environment(\.cfTheme) var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("appearance"))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(theme.textStrong)

                    Text("Customize how clipboard items appear in the menu")
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSubtle)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                // Settings Rows
                VStack(spacing: 0) {
                    CFSettingsRow(
                        label: "Theme",
                        hint: "Choose light, dark, or follow system appearance"
                    ) {
                        CFSegmentedControl(
                            selection: Binding(
                                get: {
                                    ["auto", "light", "dark"].firstIndex(of: appearanceMode) ?? 0
                                },
                                set: { index in
                                    appearanceMode = ["auto", "light", "dark"][index]
                                    // TODO: Update app theme
                                }
                            ),
                            options: ["Auto", "Light", "Dark"],
                            columns: 3
                        )
                    }

                    CFSettingsRow(
                        label: L("view_mode"),
                        hint: L("view_mode_description")
                    ) {
                        CFSegmentedControl(
                            selection: Binding(
                                get: {
                                    ["simple", "organized"].firstIndex(of: viewMode) ?? 1
                                },
                                set: { index in
                                    viewMode = ["simple", "organized"][index]
                                }
                            ),
                            options: [L("simple_mode"), L("organized_mode")],
                            columns: 2
                        )
                    }

                    CFSettingsRow(
                        label: L("show_icons"),
                        hint: "Display type icons (text, image, link) next to items"
                    ) {
                        CFToggle(isOn: $showIcons)
                    }

                    CFSettingsRow(
                        label: L("show_thumbnails"),
                        hint: "Show image previews and color swatches"
                    ) {
                        CFToggle(isOn: $showThumbnails)
                    }

                    CFSettingsRow(
                        label: L("number_menu_items"),
                        hint: "Add keyboard shortcuts 1-9, 0 to menu items"
                    ) {
                        CFToggle(isOn: $menuItemsNumbered)
                    }

                    CFSettingsRow(
                        label: L("max_title_length"),
                        hint: "\(Int(maxTitleLength)) \(L("characters"))",
                        isLast: true
                    ) {
                        CFSlider(
                            value: $maxTitleLength,
                            range: 20...100,
                            displayValue: "\(Int(maxTitleLength))"
                        )
                    }
                }
                .padding(20)
                .background(theme.surface)
                .cornerRadius(12)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .background(theme.surfaceDeep)
    }
}

#Preview {
    AppearanceSettingsView()
        .cfAutoTheme()
}
