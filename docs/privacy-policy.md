# ClipFlow Privacy Policy

Effective: November 20, 2026

ClipFlow is a clipboard manager and text expander for macOS. It works entirely on your Mac. It has no account, no server, no analytics and no advertising, and it does not send anything over the network.

## What ClipFlow keeps

- **Clipboard history.** The text, links, images, colors and file paths you copy are stored on your Mac, in `~/Library/Application Support/ClipFlow/`, with every format the copying app offered (such as rich text and HTML) and the name of the app that was in front when you copied. The history keeps the number of items you choose in Preferences, plus the items you pin. ClipFlow skips items that other apps mark as confidential or transient, such as passwords copied from a password manager, and what you copy while an app you excluded in Preferences is in front.
- **Snippets.** Your snippets, groups and their usage counts are stored in the same place.
- **Settings.** Your preferences are stored in the standard macOS preferences file for ClipFlow.

None of this leaves your Mac unless you export it yourself to a file you choose.

## What ClipFlow reads while you type

Text expansion needs the **Input Monitoring** permission. ClipFlow keeps at most the last 64 characters you typed, in memory, to recognize an abbreviation such as `.sig`. Those characters are never written to disk, logged or sent anywhere. Older characters are discarded as you keep typing, and all of them when you click, switch apps, or press Return or Tab.

The **Accessibility** permission is used only to type the expansion and to paste the clip you pick.

## Text in images and on the screen

ClipFlow reads text in images with Apple's on-device text recognition. Nothing is sent anywhere for this.

- **Copy text from screen.** Only when you press its shortcut and select an area, ClipFlow captures that area with the **Screen Recording** permission. The text found in it goes to the clipboard and history, and the image is kept as a clip unless you turn that off in Preferences → Image Text.
- **Finding images by their text.** When this is on, ClipFlow reads the text in the image clips already in your history and stores it with each clip, so search can find them. Turn it off in Preferences → Image Text.

## What ClipFlow shares

Nothing. ClipFlow makes no network requests. The GitHub, credits and license links in the About window open in your browser.

## Removing your data

Turn off **Launch at login** in Preferences, quit ClipFlow and delete the app. Then delete the `~/Library/Application Support/ClipFlow/` folder and run `defaults delete io.benesh.clipflow` in Terminal.

You can also clear the clipboard history at any time, from Preferences, from the history window, or with a keyboard shortcut you set in Preferences. Pinned items stay until you unpin or delete them.

## Changes

If this policy changes, the new version will be published here with a new effective date.

## Contact

Open an issue at https://github.com/relbns/ClipFlow/issues.
