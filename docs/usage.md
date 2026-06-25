# Usage

This repo is meant for a small group of trusted friends. It helps install and configure the official Karabiner-Elements app, then applies a few starter keyboard rules.

## Before You Start

You need:

- macOS.
- Node.js 20 or newer.
- Git, or GitHub Desktop.
- Homebrew if you want one-click install from the setup page.
- Admin access to approve Karabiner-Elements permissions in macOS Settings.

Karabiner+ does not ship its own keyboard driver. Karabiner-Elements handles the real keyboard remapping.

## Run It

```bash
git clone https://github.com/jdavies69/karabiner-plus.git
cd karabiner-plus
npm start
```

Open the local URL shown in Terminal if your browser does not open automatically.

## What The Buttons Do

- Check status: shows whether Karabiner-Elements is installed, which version is found, the active profile, and whether Homebrew is available.
- Install Karabiner: runs the Homebrew cask install for official Karabiner-Elements. If Homebrew is not available, use the official download page instead.
- Open download page: opens the official Karabiner-Elements website.
- Open Karabiner Settings: opens the official settings app so you can approve macOS permissions and check rules.
- Back up config: copies your current Karabiner config to `~/.config/karabiner/backups/`.
- Apply presets: writes the selected starter rules into the selected Karabiner profile after checking for obvious duplicate triggers.
- Restore backup: restores a selected backup and first creates a pre-restore backup of the current config.

## Starter Presets

- Caps Lock: tap for Escape, hold for Control.
- Right Command navigation: Right Command + H/J/K/L sends left/down/up/right arrows.
- Right Command forward delete: Right Command + Delete sends forward delete.

Starter rules are labeled with `[Karabiner+]`. Reapplying presets replaces those starter rules without intentionally touching your other Karabiner rules.

## Rollback

Every config write creates a backup first:

```text
~/.config/karabiner/backups/karabiner-<timestamp>.json
```

To roll back from the setup page, choose a backup in Restore backup and click Restore selected. To roll back manually, copy the backup you want back to:

```text
~/.config/karabiner/karabiner.json
```

Karabiner-Elements usually reloads automatically. If not, open Karabiner Settings or restart Karabiner-Elements.

You can also remove individual starter rules in Karabiner Settings under Complex Modifications. Look for rules beginning with `[Karabiner+]`.

## Known Limitations

- macOS only.
- Not a packaged or notarized `.app`; it runs as a local Node.js helper.
- Homebrew install only works if Homebrew is already installed.
- Conflict detection only catches obvious duplicate Karabiner triggers in the selected profile.
- It does not inspect every shortcut used by every Mac app.
- It does not uninstall Karabiner-Elements or remove non-starter Karabiner rules.
