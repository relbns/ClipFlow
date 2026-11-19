# ClipFlow Privacy Policy

Effective: November 20, 2026

ClipFlow is a clipboard manager and text expander for macOS. It works entirely on your Mac. It has no account, no server, no analytics and no advertising, and it does not send anything over the network.

## What ClipFlow keeps

- **Clipboard history.** The text, links, images and colors you copy are stored on your Mac, in `~/Library/Application Support/ClipFlow/`. The history keeps the number of items you choose in Preferences. ClipFlow skips items that other apps mark as confidential or transient, such as passwords copied from a password manager, and it skips the apps you exclude in Preferences.
- **Snippets.** Your snippets, groups and their usage counts are stored in the same place.
- **Settings.** Your preferences are stored in the standard macOS preferences file for ClipFlow.

None of this leaves your Mac unless you export it yourself to a file you choose.

## What ClipFlow reads while you type

Text expansion needs the **Input Monitoring** permission. ClipFlow keeps only the last few characters you typed, in memory, to recognize an abbreviation such as `.sig`. Those characters are never written to disk, logged or sent anywhere, and they are discarded as you keep typing.

The **Accessibility** permission is used only to type the expansion and to paste the clip you pick.

## What ClipFlow shares

Nothing. ClipFlow makes no network requests. The GitHub, credits and license links in the About window open in your browser.

## Removing your data

Quit ClipFlow, delete the app, then delete `~/Library/Application Support/ClipFlow/` and `~/Library/Preferences/io.benesh.clipflow.plist`. You can also clear the clipboard history at any time in Preferences, or with its keyboard shortcut.

## Changes

If this policy changes, the new version will be published here with a new effective date.

## Contact

Open an issue at https://github.com/relbns/ClipFlow/issues.
