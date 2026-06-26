# Karabiner+

Karabiner+ is a native macOS helper for setting up official [Karabiner-Elements](https://karabiner-elements.pqrs.org/), creating safe shortcuts, and getting local shortcut recommendations from the apps you actually use.

It does not bundle, fork, or replace Karabiner-Elements. Karabiner-Elements still handles the keyboard driver and remapping engine; Karabiner+ owns the friendlier setup, backups, shortcut creation, and recommendations.

## What You Get

- A native windowed macOS app, not a menu bar item.
- Start screen with the clearest next action.
- Connect checks official Karabiner-Elements, config readiness, permissions, and backups.
- Backup before every config write.
- Safety recovery center for backup history, restore, and undoing the latest Karabiner+ change.
- Shortcut Coach: opt-in local active-app usage tracking while the app is open.
- Create: build custom remaps from safe templates, manual pickers, or in-app shortcut capture without editing Karabiner JSON.
- Saved Studio shortcuts are preserved as a list instead of being overwritten one at a time.
- App-aware recommendation packs for Slack, browsers, Messages, media apps, and Preview.
- Conservative conflict checks before writes.
- GitHub update check with a copyable pull-and-rebuild command for source-built installs.

## Privacy

Shortcut Coach is off until you start it. While tracking is on, Karabiner+ stores only:

- active app name
- bundle identifier when available
- active time estimate
- last seen time

It does not collect keystrokes, window titles, document contents, or cloud data. Usage history stays local on your Mac and can be deleted from the app.

## Build And Run

```bash
git clone https://github.com/jdavies69/karabiner-plus.git
cd karabiner-plus
./build.sh
open "build/Karabiner+.app"
```

The repo currently builds from source with Swift command-line tools. A signed/notarized release is not part of this first version.

## Unsigned Alpha Package

You can make an unsigned zip for GitHub Releases:

```bash
./scripts/package-release.sh
```

The zip lands in `dist/`. Because there is no Apple Developer ID yet, macOS may require users to right-click `Karabiner+.app` and choose `Open`. A smoother public release needs Developer ID signing and Apple notarization.

## Updating

Open `Safety` -> `Check for Updates`. Karabiner+ compares the current build commit with the latest `main` branch commit on GitHub. If an update exists, copy the update command from the app and run it in Terminal.

## Legacy Prototype

The earlier browser prototype is still available:

```bash
npm start
```

Use it only as a fallback while the native app matures.

## Verification

```bash
swift run KarabinerPlusCoreCheck
swift build
npm test
npm run lint
```

`swift test` is not used in this repo right now because the current local Command Line Tools install cannot import XCTest. `KarabinerPlusCoreCheck` is the Swift verification runner.
