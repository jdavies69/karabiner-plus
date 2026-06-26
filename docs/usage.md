# Usage

Karabiner+ is meant for a small group of trusted Mac users who want Karabiner-Elements power without starting in Karabiner JSON.

## Before You Start

You need:

- macOS.
- Swift command-line tools.
- Git, or GitHub Desktop.
- Homebrew if you want one-click Karabiner install from the app.
- Admin access to approve Karabiner-Elements permissions in macOS Settings.

Karabiner+ does not ship its own keyboard driver. Official Karabiner-Elements handles the real keyboard remapping.

## Run The Native App

```bash
git clone https://github.com/jdavies69/karabiner-plus.git
cd karabiner-plus
./build.sh
open "build/Karabiner+.app"
```

## Main Sections

- Start: see the next best action and jump into setup, shortcut creation, or coaching.
- Connect: open official Karabiner-Elements, check config readiness, open permission screens, and create backups.
- Coach: start or pause local usage tracking, delete usage history, view top apps, and apply recommended shortcut packs.
- Create: create global custom remaps from safe templates or from scratch, then save them with backup.
- Safety: review local privacy, config-write behavior, backups, paths, and GitHub updates.

## Shortcut Coach

Tracking starts only after you press Start Tracking. It runs only while Karabiner+ is open.

Karabiner+ tracks:

- active app name
- bundle identifier when available
- active time estimate
- last seen time

Karabiner+ does not track:

- keystrokes
- window titles
- document contents
- cloud data

Usage history is stored locally in UserDefaults and can be deleted from the Coach screen.

## Create Shortcuts

Create currently builds global remaps: when you press one key or key combination, Karabiner sends another. Choose a name, what you press, and what it should act like. Karabiner+ previews the result in plain English and warns about risky common Command shortcuts, no-op remaps, and plain key remaps that would affect normal typing or editing everywhere.

Saving a shortcut writes the full Karabiner+ Studio shortcut list, so existing Studio shortcuts shown in the app are preserved. Unrelated Karabiner rules are not touched.

Custom rules are labeled `[Karabiner+] Custom:`. Recommended rules are labeled `[Karabiner+] Recommended:`. Older `[Karabiner Starter]` rules are preserved for compatibility.

## Backup And Rollback

Every config write creates a backup first:

```text
~/.config/karabiner/backups/karabiner-<timestamp>.json
```

To roll back manually, copy the backup you want back to:

```text
~/.config/karabiner/karabiner.json
```

Karabiner-Elements usually reloads automatically. If not, open Karabiner Settings or restart Karabiner-Elements.

## Updates

Karabiner+ is source-built right now, so it does not silently auto-update. Open Safety and press Check for Updates. The app compares the commit embedded during `./build.sh` with GitHub `main`.

If an update is available, use Copy Update Command. It copies a command like:

```bash
cd "<your karabiner-plus repo>" && git pull --ff-only && ./build.sh && open "build/Karabiner+.app"
```

Run that in Terminal to pull the newest code, rebuild the app, and reopen it.

## Legacy Browser Prototype

The original local browser UI is still available:

```bash
npm start
```

It remains useful as a fallback and as reference behavior while the native app matures.
