import SwiftUI

struct TextExpansionSettingsView: View {
    @AppStorage("textExpansionEnabled") private var expansionEnabled = true
    @AppStorage("expandAfter") private var expandAfter = "delimiter"
    @AppStorage("playSoundOnExpand") private var playSound = false
    @ObservedObject private var permissions = PermissionService.shared

    private let triggers = ["delimiter", "space", "tab", "enter", "any"]

    var body: some View {
        SettingsPage {
            if !permissions.isGranted {
                CFBanner.accessibility(
                    title: L("perm_title"),
                    message: L("perm_message"),
                    action: AnyView(
                        CFToolbarBtn(label: L("perm_button"), primary: true) {
                            permissions.request()
                            if !permissions.isGranted {
                                permissions.openSystemSettings()
                            }
                        }
                    )
                )
                .padding(.bottom, 8)
            }

            CFSettingsRow(label: L("pref_text_expansion"), hint: L("pref_text_expansion_hint")) {
                CFToggle(isOn: $expansionEnabled).accessibilityLabel(L("pref_text_expansion"))
            }
            CFSettingsRow(label: L("pref_default_trigger"), hint: L("pref_default_trigger_hint")) {
                CFSegmentedControl(
                    selection: Binding(
                        get: { triggers.firstIndex(of: expandAfter) ?? 0 },
                        set: { expandAfter = triggers[$0] }
                    ),
                    options: triggers.map { L("trigger_\($0)") }
                )
            }
            CFSettingsRow(label: L("pref_sound"), hint: L("pref_sound_hint")) {
                CFToggle(isOn: $playSound).accessibilityLabel(L("pref_sound"))
            }
            CFSettingsRow(label: L("pref_expansion_excluded"), hint: L("pref_expansion_excluded_hint"), isLast: true) {
                ExcludedAppsField(scope: .expansion)
            }
        }
        .onAppear { permissions.refresh() }
    }
}

/// Pills for the apps excluded in one scope, plus an "Add app" pill.
struct ExcludedAppsField: View {
    let scope: ExcludedApp.Scope
    @AppStorage(AppExclusions.defaultsKey) private var json = "[]"
    @Environment(\.cfTheme) private var theme

    private var apps: [ExcludedApp] {
        AppExclusions.decode(json).filter { $0.isExcluded(from: scope) }
    }

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(apps) { app in
                CFPill(text: app.name, icon: appIcon(app.bundleID), closable: true) {
                    json = AppExclusions.encode(AppExclusions.decode(json).removing(bundleID: app.bundleID, from: scope))
                }
                .accessibilityLabel(app.name)
            }
            Button {
                AppExclusions.pickApplication { bundleID, name in
                    json = AppExclusions.encode(AppExclusions.decode(json).adding(bundleID: bundleID, name: name, to: scope))
                }
            } label: {
                HStack(spacing: 4) {
                    CFIcon(type: .plus, size: 11, stroke: 1.8)
                    Text(L("add_app")).font(.system(size: 12))
                }
                .foregroundColor(theme.textMuted)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .overlay(Capsule().strokeBorder(theme.fill3, style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func appIcon(_ bundleID: String) -> AnyView? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return AnyView(Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable())
    }
}

/// Wraps its children onto as many lines as needed, like CSS flex-wrap.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews, width: bounds.width)
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !rows[rows.count - 1].indices.isEmpty, rows[rows.count - 1].width + spacing + size.width > width {
                let last = rows[rows.count - 1]
                rows.append(Row(y: last.y + last.height + spacing))
            }
            var row = rows[rows.count - 1]
            row.width += (row.indices.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}
