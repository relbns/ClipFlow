# Mac App Store: preparation plan

ClipFlow is distributed as a download from GitHub Releases. This document is the plan for a later Mac App Store release. It is not scheduled. Nothing here is required for the download.

## Before the Apple Developer account

Each item can be done and tested without the paid account.

1. **A sandboxed build next to the current one.** The current build stays as it is. A second build runs inside the App Sandbox, as the Mac App Store requires. A sandboxed build (`./build-app.sh --sandbox`) was tested by hand: text expansion, paste-on-pick and keyboard navigation work.
   - Inside the sandbox, data lives in the app's container (`~/Library/Containers/io.benesh.clipflow/`). Without a migration, someone moving from the download to the App Store version starts with an empty history and no snippets. Add a `container-migration.plist` that moves `~/Library/Application Support/ClipFlow/` and the preferences into the container.
2. **An Xcode project that archives.** `project.yml` describes the project, but XcodeGen is not installed and the committed `ClipFlow.xcodeproj` may be out of date. Target: `xcodebuild archive` succeeds locally with the sandbox entitlements and the hardened runtime.
3. **`Info.plist` cleanup.**
   - Remove `NSAccessibilityUsageDescription`: macOS has no such key for this permission, and its text describes the wrong one.
   - Add `LSApplicationCategoryType` = `public.app-category.productivity`.
   - Add `ITSAppUsesNonExemptEncryption` = `false`, so each upload skips the encryption questionnaire.
4. **Privacy manifest (`PrivacyInfo.xcprivacy`).** Most sources say it is not yet required on macOS, but it costs little: no tracking, no collected data, `UserDefaults` with reason `CA92.1`.
5. **Nothing that should not ship.**
   - Keep the snapshot modes (`--render-snapshots`, `--render-icon`) out of the App Store build.
   - Remove sample text, and any mention of iCloud until sync exists.
   - Confirm a 1024×1024 icon is in the asset catalog.
6. **Store page material.**
   - Description and keywords in English and Hebrew.
   - Screenshots at 2880×1800, rendered by the snapshot tool.
   - The privacy policy (`docs/privacy-policy.md`) at a public URL, which App Store Connect requires. GitHub Pages on this repository is enough.
7. **App Review risks, written down before the first submission.**
   - Why Input Monitoring is needed: text expansion is the core feature, and only the last few typed characters are kept, in memory.
   - What the privacy policy says about keystrokes.
   - Whether recent macOS versions warn when an app reads the pasteboard, and what that means for a clipboard manager.

## With the Apple Developer account

1. Register the App ID `io.benesh.clipflow` and create the app in App Store Connect.
   - The name "ClipFlow" may be taken: names are unique across the App Store, and an iPhone app called "ClipFlow - Quick Media Editor" exists. The record shows whether "ClipFlow" alone is free.
2. Create the Apple Distribution and Mac Installer certificates and a Mac App Store provisioning profile.
3. Archive, validate and upload. Test through TestFlight on a second Mac, then submit for review.
4. Developer ID signing and notarization for the GitHub download (`./build-app.sh --notarize`). macOS then opens it without the "Open Anyway" step.
5. iCloud sync through CloudKit, which needs the account.

## Decisions already made

- Bundle ID: `io.benesh.clipflow`.
- License: MIT.
