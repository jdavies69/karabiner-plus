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

- Setup: refresh local status, install official Karabiner through Homebrew, open the official download page, open Karabiner, and create backups.
- Coach: start or pause local usage tracking, delete usage history, view top apps, and apply recommended shortcut packs.
- Studio: create one global custom shortcut and apply it safely with backup.
- Safety: review local privacy and config-write behavior.

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

## Shortcut Studio

Shortcut Studio V1 creates global shortcuts only. Choose a name, source key, source modifiers, output key, and output modifiers. Karabiner+ previews the shortcut and warns about risky common Command shortcuts before applying.

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

## Legacy Browser Prototype

The original local browser UI is still available:

```bash
npm start
```

It remains useful as a fallback and as reference behavior while the native app matures.
