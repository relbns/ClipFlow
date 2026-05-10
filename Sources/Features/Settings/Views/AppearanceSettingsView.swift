import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("viewMode") private var viewMode = "organized"
    @AppStorage("showIcons") private var showIcons = true
    @AppStorage("showThumbnails") private var showThumbnails = true
    @AppStorage("menuItemsNumbered") private var menuItemsNumbered = true
    @AppStorage("maxTitleLength") private var maxTitleLength = 50.0

    var body: some View {
        Form {
            Section(L("menu_style")) {
                Picker(L("view_mode"), selection: $viewMode) {
                    Text(L("simple_mode")).tag("simple")
                    Text(L("organized_mode")).tag("organized")
                }
                .pickerStyle(.radioGroup)

                Text(L("view_mode_description"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(L("menu_items")) {
                Toggle(L("show_icons"), isOn: $showIcons)
                Toggle(L("show_thumbnails"), isOn: $showThumbnails)
                Toggle(L("number_menu_items"), isOn: $menuItemsNumbered)

                VStack(alignment: .leading) {
                    Text("\(L("max_title_length")): \(Int(maxTitleLength)) \(L("characters"))")
                        .font(.caption)

                    Slider(value: $maxTitleLength, in: 20...100, step: 5)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    AppearanceSettingsView()
}
