# Karabiner+

Karabiner+ is a small macOS setup helper for friends who want a few safe keyboard tweaks without learning Karabiner-Elements first.

It does not bundle, fork, or replace Karabiner. It installs and configures the official [Karabiner-Elements](https://karabiner-elements.pqrs.org/) app, then writes starter rules to your local Karabiner config.

## What You Get

- Caps Lock: tap for Escape, hold for Control.
- Right Command + H/J/K/L: arrow navigation.
- Right Command + Delete: forward delete.
- A backup before every config change.
- Basic conflict checks before presets are applied.

## Prerequisites

- macOS.
- Node.js 20 or newer.
- Git, or GitHub Desktop.
- Homebrew is optional. If present, the app can install official Karabiner-Elements with `brew install --cask karabiner-elements`.
- macOS admin access is usually needed for Karabiner-Elements permissions.

## Start

```bash
git clone https://github.com/jdavies69/karabiner-plus.git
cd karabiner-plus
npm start
```

`npm start` launches a local setup page. Open the shown local URL if your browser does not open automatically, then work through the buttons:

- Check status: confirms whether official Karabiner-Elements and Homebrew are installed.
- Install Karabiner: installs official Karabiner-Elements through Homebrew when available.
- Open download page: use this if Homebrew is not installed.
- Open Karabiner Settings: finish required macOS permissions for keyboard monitoring and virtual keyboard access.
- Back up config: saves the current `~/.config/karabiner/karabiner.json`.
- Apply presets: writes the selected starter rules after checking for obvious conflicts.
- Restore backup: restores a previous backup and creates a pre-restore backup first.

More detail: [docs/usage.md](docs/usage.md).

## Backup And Rollback

Before changing your Karabiner config, Karabiner+ creates a timestamped backup in:

```text
~/.config/karabiner/backups/
```

Use the Restore backup panel in the setup page, or copy the backup you want over:

```text
~/.config/karabiner/karabiner.json
```

Karabiner-Elements usually reloads that file automatically. If it does not, open Karabiner Settings or restart Karabiner-Elements.

## Known Limitations

- macOS only.
- This is a local helper, not a packaged Mac app.
- Conflict checks are conservative and only cover obvious duplicate Karabiner triggers in the selected profile.
- It does not discover every app-specific shortcut on your Mac.
- It does not uninstall Karabiner-Elements.
