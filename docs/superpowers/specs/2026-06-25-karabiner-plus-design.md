# Karabiner+ Design

## Goal

Karabiner+ is a small personal onboarding app for macOS that helps a user install official Karabiner-Elements, understand setup status, apply safe starter presets, and avoid obvious shortcut conflicts.

## Product Shape

The app is a standalone companion, not a Karabiner fork. It uses official Karabiner-Elements for the driver, background services, EventViewer, and settings window. Karabiner+ owns only onboarding, local checks, backups, preset generation, and configuration writes.

The native version ships as a GitHub repo with one primary build path:

```bash
./build.sh
open "build/Karabiner+.app"
```

The older local browser UI remains available with `npm start` as a fallback. The native app can install Karabiner via Homebrew when Homebrew is available, open the official download page otherwise, open Karabiner, create backups, track usage with consent, recommend packs, and apply custom shortcuts.

## Architecture

The legacy browser prototype has three layers:

- `src/core`: pure Karabiner preset, conflict, and config merge logic.
- `src/server.js`: local HTTP API and static UI host.
- `src/cli.js`: command-line entry point for friends who clone the repo.

Karabiner configuration is written to `~/.config/karabiner/karabiner.json`. Before any write, the app creates a timestamped backup in `~/.config/karabiner/backups`. Karabiner watches this file and reloads updates itself.

## Presets

Initial presets are deliberately conservative:

- Caps Lock: Escape when tapped, Control when held.
- Right Command + H/J/K/L: arrow navigation.
- Right Command + Delete: forward delete.

Each generated rule description starts with `[Karabiner+]`, so the app can replace its own rules without touching user-created or imported rules.

## Conflict Handling

Conflict detection compares selected preset manipulators against each other and existing non-starter rules in the selected Karabiner profile. A conflict is reported when two rules use the same source key plus mandatory modifier set. The UI blocks apply when conflicts are detected.

The app also labels its chosen presets as low-risk because they avoid common global macOS shortcuts like Command-Space, Command-Tab, Command-Q, Command-W, Command-C, Command-V, Command-X, and Command-Z.

## Out Of Scope

- Forking or repackaging Karabiner-Elements.
- Maintaining a custom virtual HID driver.
- App notarization and packaged `.app` distribution.
- Full cross-application shortcut discovery.
- Cloud backend.

## Later

The current product direction is the native Swift app in `Sources/KarabinerPlusApp`, with the browser-hosted UI kept as a fallback.
