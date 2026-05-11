import SwiftUI

/// Comprehensive showcase of all ClipFlow components for testing light/dark modes
struct CFShowcase: View {
    @State private var toggleOn = true
    @State private var textInput = "Sample text"
    @State private var sliderValue: Double = 50
    @State private var segmentSelection = 1

    @Environment(\.cfTheme) var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                headerSection
                iconSection
                controlsSection
                buttonsSection
                chipsSection
                badgesSection
                stepsSection
                statCardsSection
                sectionLabelsSection
                footerButtonsSection
                bannersSection
                aboutPreview
                welcomePreview
            }
            .padding(40)
        }
        .frame(width: 900, height: 1200)
        .background(theme.surfaceDeep)
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            ClipFlowMark(size: 80)

            Text("ClipFlow Component Showcase")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(theme.textStrong)

            Text("Testing all components in current theme")
                .font(.system(size: 14))
                .foregroundColor(theme.textMid)
        }
    }

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Icons")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 8), spacing: 20) {
                iconDemo(.search, "search")
                iconDemo(.clock, "clock")
                iconDemo(.image, "image")
                iconDemo(.text, "text")
                iconDemo(.link, "link")
                iconDemo(.bolt, "bolt")
                iconDemo(.star, "star")
                iconDemo(.folder, "folder")
                iconDemo(.gear, "gear")
                iconDemo(.cloud, "cloud")
                iconDemo(.check, "check")
                iconDemo(.plus, "plus")
                iconDemo(.trash, "trash")
                iconDemo(.lock, "lock")
                iconDemo(.sparkles, "sparkles")
                iconDemo(.hebrew, "hebrew")
            }
        }
        .padding(24)
        .background(theme.surface)
        .cornerRadius(12)
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionTitle("Controls")

            CFSettingsRow(label: "Toggle", hint: "On/off switch") {
                HStack {
                    CFToggle(isOn: $toggleOn)
                    Text(toggleOn ? "On" : "Off")
                        .font(.system(size: 12))
                        .foregroundColor(theme.textMuted)
                }
            }

            CFSettingsRow(label: "Select", hint: "Dropdown picker") {
                CFSelect(value: "Space, Tab or Enter")
            }

            CFSettingsRow(label: "Text Input") {
                CFInput(text: $textInput, placeholder: "Type here...")
            }

            CFSettingsRow(label: "Monospace Input") {
                CFInput(text: .constant(".sig"), placeholder: "Abbreviation", mono: true, prefix: ".")
            }

            CFSettingsRow(label: "Slider") {
                CFSlider(value: $sliderValue, range: 10...100)
            }

            CFSettingsRow(label: "Segmented Control", isLast: true) {
                CFSegmentedControl(
                    selection: $segmentSelection,
                    options: ["Space", "Tab", "Enter", "Punct.", "Any", "Manual"],
                    columns: 3
                )
            }
        }
        .padding(24)
        .background(theme.surface)
        .cornerRadius(12)
    }

    private var buttonsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionTitle("Buttons")

            VStack(alignment: .leading, spacing: 12) {
                Text("Toolbar Buttons")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.text)

                HStack(spacing: 8) {
                    CFToolbarBtn(
                        icon: AnyView(CFIcon(type: .plus, size: 12)),
                        label: "New"
                    )
                    CFToolbarBtn(label: "Duplicate")
                    CFToolbarBtn(label: "Save", primary: true)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Link & Icon Buttons")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.text)

                HStack(spacing: 12) {
                    CFLinkBtn(
                        icon: AnyView(CFIcon(type: .link, size: 13)),
                        label: "GitHub"
                    )
                    CFIconBtn(icon: AnyView(CFIcon(type: .gear, size: 14)))
                    CFIconBtn(icon: AnyView(CFIcon(type: .trash, size: 14)))
                    CFDangerBtn(label: "Delete")
                }
            }
        }
        .padding(24)
        .background(theme.surface)
        .cornerRadius(12)
    }

    private var chipsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionTitle("Chips & Badges")

            VStack(alignment: .leading, spacing: 16) {
                Text("Variable Chips")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.text)

                HStack(spacing: 6) {
                    CFVarChip(text: "{date}")
                    CFVarChip(text: "{time}")
                    CFVarChip(text: "{clipboard}")
                    CFVarChip(text: "{cursor}")
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                Text("Keyboard Shortcuts")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.text)

                HStack(spacing: 8) {
                    CFKBD(text: "⌘E")
                    CFKBD(text: "⌘,")
                    CFKBD(text: "1", dim: true)
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                Text("Pills & Tags")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.text)

                HStack(spacing: 6) {
                    CFPill(text: "Terminal", closable: true)
                    CFPill(text: "Xcode", closable: true)
                    CFAddPill(text: "+ Add app")
                    CFCountBadge(count: 14)
                    CFVersionTag(type: .alpha)
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                Text("Status Chips")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.text)

                HStack(spacing: 12) {
                    CFStatusChip(status: .saved)
                    CFStatusChip(status: .saving)
                    CFStatusChip(status: .error)
                }
            }
        }
        .padding(24)
        .background(theme.surface)
        .cornerRadius(12)
    }

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionTitle("Gradient Badges")

            VStack(alignment: .leading, spacing: 16) {
                Text("Settings Tab Icons (28×28)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.text)

                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        CFGradientBadge(
                            icon: .gear,
                            accent: Color(red: 0.55, green: 0.03, blue: 0.85)
                        )
                        Text("General")
                            .font(.system(size: 11))
                            .foregroundColor(theme.textMid)
                    }

                    VStack(spacing: 4) {
                        CFGradientBadge(
                            icon: .star,
                            accent: Color(red: 0.85, green: 0.50, blue: 0.20)
                        )
                        Text("Appearance")
                            .font(.system(size: 11))
                            .foregroundColor(theme.textMid)
                    }

                    VStack(spacing: 4) {
                        CFGradientBadge(
                            icon: .bolt,
                            accent: Color(red: 0.47, green: 0.44, blue: 1.0)
                        )
                        Text("Expansion")
                            .font(.system(size: 11))
                            .foregroundColor(theme.textMid)
                    }

                    VStack(spacing: 4) {
                        CFGradientBadge(
                            icon: .key,
                            accent: Color(red: 0.40, green: 0.80, blue: 0.50)
                        )
                        Text("Hotkeys")
                            .font(.system(size: 11))
                            .foregroundColor(theme.textMid)
                    }
                }

                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        CFGradientBadge(
                            icon: .cloud,
                            accent: Color(red: 0.30, green: 0.60, blue: 1.0)
                        )
                        Text("Sync")
                            .font(.system(size: 11))
                            .foregroundColor(theme.textMid)
                    }

                    VStack(spacing: 4) {
                        CFGradientBadge(
                            icon: .lock,
                            accent: Color(red: 0.35, green: 0.75, blue: 0.85)
                        )
                        Text("Privacy")
                            .font(.system(size: 11))
                            .foregroundColor(theme.textMid)
                    }

                    VStack(spacing: 4) {
                        CFGradientBadge(
                            icon: .hebrew,
                            accent: Color(red: 0.85, green: 0.40, blue: 0.75)
                        )
                        Text("Language")
                            .font(.system(size: 11))
                            .foregroundColor(theme.textMid)
                    }

                    Spacer()
                }
            }
        }
        .padding(24)
        .background(theme.surface)
        .cornerRadius(12)
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionTitle("Step Indicators")

            VStack(alignment: .leading, spacing: 16) {
                Text("Welcome Screen Steps (3 states)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.text)

                VStack(spacing: 12) {
                    CFStepIndicator(
                        number: 1,
                        state: .done,
                        title: "Pin ClipFlow to your menubar",
                        bodyText: "ClipFlow lives up here — there's no Dock icon."
                    )

                    CFStepIndicator(
                        number: 2,
                        state: .active,
                        title: "Grant Accessibility permission",
                        bodyText: "Required so snippets can expand as you type."
                    )

                    CFStepIndicator(
                        number: 3,
                        state: .default,
                        title: "Try your first snippet",
                        bodyText: "We've added .dd for today's date."
                    )
                }
            }
        }
        .padding(24)
        .background(theme.surface)
        .cornerRadius(12)
    }

    private var statCardsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionTitle("Stat Cards")

            VStack(alignment: .leading, spacing: 16) {
                Text("Snippet Statistics (2×2 grid)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.text)

                LazyVGrid(columns: [GridItem(), GridItem()], spacing: 8) {
                    CFStatCard(value: "184", label: "expansions")
                    CFStatCard(value: "27 min", label: "time saved")
                    CFStatCard(value: "Mail", label: "top app")
                    CFStatCard(value: "May 9", label: "last used")
                }
            }
        }
        .padding(24)
        .background(theme.surface)
        .cornerRadius(12)
    }

    private var sectionLabelsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionTitle("Section Labels")

            VStack(alignment: .leading, spacing: 16) {
                Text("Sidebar Headers")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.text)

                VStack(spacing: 0) {
                    CFSectionLabel("LIBRARY")
                    Rectangle()
                        .fill(theme.fill1)
                        .frame(height: 40)

                    CFSectionLabel("GROUPS") {
                        print("Add group")
                    }
                    Rectangle()
                        .fill(theme.fill1)
                        .frame(height: 40)
                }
                .background(theme.surfaceAlt)
                .cornerRadius(8)
            }
        }
        .padding(24)
        .background(theme.surface)
        .cornerRadius(12)
    }

    private var footerButtonsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionTitle("Footer Row Buttons")

            VStack(alignment: .leading, spacing: 16) {
                Text("MenuBar Footer Actions")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.text)

                VStack(spacing: 0) {
                    CFFooterRowBtn(icon: .sparkles, label: "Snippet Editor…", kbd: "⌘E") {}
                    CFFooterRowBtn(icon: .gear, label: "Preferences…", kbd: "⌘,") {}
                    Divider()
                    CFFooterRowBtn(icon: .trash, label: "Clear history") {}
                    CFFooterRowBtn(icon: .power, label: "Quit ClipFlow", kbd: "⌘Q", danger: true) {}
                }
                .background(theme.fill1)
                .cornerRadius(8)
            }
        }
        .padding(24)
        .background(theme.surface)
        .cornerRadius(12)
    }

    private var bannersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Banners")

            CFBanner.accessibility(
                action: AnyView(
                    CFToolbarBtn(label: "Open Settings", primary: true)
                )
            )

            CFBanner.info(
                icon: AnyView(CFIcon(type: .cloud, size: 18, stroke: 1.8)),
                title: "Sync enabled",
                message: "Your data is synced across devices."
            )

            CFBanner.success(
                icon: AnyView(CFIcon(type: .check, size: 18, stroke: 1.8)),
                title: "Export complete",
                message: "Successfully exported 47 snippets."
            )

            CFBanner.error(
                icon: AnyView(CFIcon(type: .circle, size: 18, stroke: 1.8)),
                title: "Connection failed",
                message: "Unable to connect. Check your network."
            )
        }
        .padding(24)
        .background(theme.surface)
        .cornerRadius(12)
    }

    private var aboutPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("About Window Preview")

            VStack(spacing: 16) {
                ClipFlowMark.heroIcon(size: 96)

                Text("ClipFlow")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(theme.textStrong)

                HStack(spacing: 8) {
                    Text("Version 1.0.0")
                        .font(.system(size: 13))
                        .foregroundColor(theme.text)

                    CFVersionTag(type: .alpha)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(30)
        }
        .padding(24)
        .background(theme.surface)
        .cornerRadius(12)
    }

    private var welcomePreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Welcome Window Preview")

            VStack(spacing: 20) {
                ClipFlowMark.heroIcon(size: 80)

                VStack(spacing: 8) {
                    Text("Welcome to ClipFlow")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(theme.textStrong)

                    Text("Modern clipboard manager + text expander")
                        .font(.system(size: 13))
                        .foregroundColor(theme.textMid)
                }

                HStack {
                    Spacer()
                    CFToolbarBtn(
                        icon: AnyView(CFIcon(type: .chevron, size: 12)),
                        label: "Get Started",
                        primary: true
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(30)
        }
        .padding(24)
        .background(theme.surface)
        .cornerRadius(12)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(theme.textStrong)
    }

    private func iconDemo(_ type: CFIcon.IconType, _ label: String) -> some View {
        VStack(spacing: 6) {
            CFIcon(type: type, size: 24, stroke: 1.8)
                .foregroundColor(theme.text)
                .frame(width: 40, height: 40)
                .background(theme.fill1)
                .cornerRadius(8)

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(theme.textSubtle)
        }
    }
}

// MARK: - Preview
#if DEBUG
struct CFShowcase_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CFShowcase()
                .cfAutoTheme()
                .previewDisplayName("Light Mode")

            CFShowcase()
                .cfAutoTheme()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}
#endif
