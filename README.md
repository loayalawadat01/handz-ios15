# Handz 15

A separate copy of the Handz iPhone app (`handz-ios`) that also runs on iOS 15,
so it can be tested on an older iPhone such as the iPhone 7.

- The main app is `handz-ios` (iOS 16 and newer). This copy doesn't change it.
- It shows on the phone as **Handz 15**, with its own app ID
  (`com.loayalawadat01.handz15`), so both apps can be installed side by side.
- It uses the same Handz server (`handz-app`) running on your Mac.

## What's different on iOS 15

On iOS 16 and newer this copy looks and works like the main app. On iOS 15:

- Long text boxes (job description, chat, reviews) are one line that scrolls sideways.
- Small pop-ups, like the new job pop-up for workers, open as full-height sheets.
- Skills on a profile scroll sideways instead of wrapping.
- Pull down to refresh only works on list screens.
- Receipt PDFs are saved as a picture of the receipt.

All of this lives in `Handz/core/DesignSystem/iOS15Support.swift`.

## Running it on a real iPhone

The app finds the server through your Mac's network name, which a build step
puts in the app (look for "Handz server address for a real iPhone" in Xcode's
build log). The iPhone and the Mac must be on the same Wi-Fi, and the server
must be running (`Start Handz.command` in `handz-app`).

## Getting updates

Quit Xcode, then double-click `Update Handz 15.command` in this folder.
