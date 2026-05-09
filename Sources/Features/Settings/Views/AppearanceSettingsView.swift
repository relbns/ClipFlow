import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("viewMode") private var viewMode = "organized"
    @AppStorage("showIcons") private var showIcons = true
    @AppStorage("showThumbnails") private var showThumbnails = true
    @AppStorage("menuItemsNumbered") private var menuItemsNumbered = true
    @AppStorage("maxTitleLength") private var maxTitleLength = 50.0

    var body: some View {
        Form {
            Section("Menu Style") {
                Picker("View Mode:", selection: $viewMode) {
                    Text("Simple (Flycut-style)").tag("simple")
                    Text("Organized (Folders)").tag("organized")
                }
                .pickerStyle(.radioGroup)

                Text("Choose between a simple flat list or organized folders")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Menu Items") {
                Toggle("Show icons", isOn: $showIcons)
                Toggle("Show thumbnails for images", isOn: $showThumbnails)
                Toggle("Number menu items (1-9, 0)", isOn: $menuItemsNumbered)

                VStack(alignment: .leading) {
                    Text("Max title length: \(Int(maxTitleLength)) characters")
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
