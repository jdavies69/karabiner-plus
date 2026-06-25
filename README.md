# Karabiner+

Karabiner+ is a native macOS helper for setting up official [Karabiner-Elements](https://karabiner-elements.pqrs.org/), creating safe shortcuts, and getting local shortcut recommendations from the apps you actually use.

It does not bundle, fork, or replace Karabiner-Elements. Karabiner-Elements still handles the keyboard driver and remapping engine; Karabiner+ owns the friendlier setup, backups, shortcut creation, and recommendations.

## What You Get

- A native windowed macOS app, not a menu bar item.
- Setup checks for Karabiner config, Homebrew, and active profile.
- Backup before every config write.
- Shortcut Coach: opt-in local active-app usage tracking while the app is open.
- Shortcut Studio: create global custom shortcuts without editing Karabiner JSON.
- App-aware recommendation packs for Slack, browsers, Messages, media apps, and Preview.
- Conservative conflict checks before writes.

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
