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

- Start: see setup progress, the next best action, and launch the first-shortcut wizard.
- Connect: open official Karabiner-Elements, check config readiness, open permission screens, and create backups.
- Coach: start or pause local usage tracking, delete usage history, view top apps, create launcher sequences, and apply recommended shortcut packs.
- Create: create global or app-specific custom remaps from safe templates, manual pickers, or shortcut capture, then review an apply summary before saving with backup.
- Safety: review local privacy, config-write behavior, restore backups, undo the latest change, inspect paths, and check GitHub updates.

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

## Launcher Sequences

Coach can turn local app history into editable Right Command launcher sequences. Karabiner+ suggests one- or two-letter codes from app names, skips apps without bundle identifiers, and lets you edit the code before applying.

Examples:

- `Right Command` then `S U` opens Superhuman.
- `Right Command` then `C O` opens Codex.
- `Right Command` then `C H` opens ChatGPT.
- `Right Command` then `M` can open Superhuman if you prefer Mail-style muscle memory.

Launcher sequences are written as one Karabiner+ owned rule. Applying them creates a backup first and preserves unrelated Karabiner rules.

## Create Shortcuts

Create builds global or app-specific remaps: when you press one key or key combination, Karabiner sends another. The first-shortcut wizard loads a safe `Caps Lock -> Escape` shortcut so new users can get to a working result quickly.

Choose a name, what you press, what it should act like, and where it works. Use Everywhere for global shortcuts, or Current App to limit the shortcut to the frontmost app's bundle identifier. If the current app does not expose a bundle identifier, Karabiner+ keeps the shortcut global and shows a message.

You can use the menus or press Capture to record a key combination while Karabiner+ is focused. Capture is local to the app and starts only after you press the button.

Karabiner+ previews the result in plain English and warns about risky common Command shortcuts, no-op remaps, and plain key remaps that would affect normal typing or editing everywhere.

Before writing, Karabiner+ shows an apply summary: Studio rules to write, Karabiner+-owned rules to replace, unrelated rules to preserve, and conflicts if any are found. Saving a shortcut writes the full Karabiner+ Studio shortcut list, so existing Studio shortcuts shown in the app are preserved. Unrelated Karabiner rules are not touched.

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

Safety also lists available backups. Use Restore Selected Backup to roll back to a previous config, or Undo Last Change to restore the backup created immediately before the latest Karabiner+ write in the current app session.

Apply summaries are previews, not backups. Use Safety restore or undo when you need to roll back after a write.

## Unsigned Release Zip

Without an Apple Developer ID, Karabiner+ can still produce an unsigned alpha zip:

```bash
./scripts/package-release.sh
```

The archive is written to `dist/`. This alpha zip is unsigned and not notarized. macOS Gatekeeper may warn that the developer cannot be verified and may block first launch. Only open it if you trust this source. For this alpha, the usual workaround is to right-click `Karabiner+.app` and choose Open; a smoother public release needs Developer ID signing and Apple notarization.

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
