# Karabiner+ Native App Design

## Goal

Karabiner+ is a native macOS windowed app that makes Karabiner-Elements approachable: install/open official Karabiner, show setup status, track active-app usage only while the app is open and explicitly enabled, recommend useful shortcut packs, and create safe custom global shortcuts.

## Product Shape

The app is not a menu bar utility. MacBook menu bars are crowded, and this product has enough workflow to deserve a real window. The first native version should open directly into the working app, not a landing page.

The app name is **Karabiner+**. It keeps Karabiner visible in copy where needed, but the friend-facing product is a calmer, more memorable helper for tailoring keyboard behavior.

## Architecture

Use a Swift-first structure:

- `Sources/KarabinerPlusCore`: testable Swift models and services for Karabiner config, shortcuts, recommendations, usage, and system status.
- `Sources/KarabinerPlusApp`: SwiftUI/AppKit windowed macOS application.
- `Sources/KarabinerPlusCoreCheck`: plain Swift verification runner for config merging, shortcut generation, recommendations, and usage accumulation.
- `build.sh`: compiles `build/Karabiner+.app` using local Swift command-line tools.

Keep the current Node/browser prototype in the repo as a reference and fallback, but the primary documented path becomes native Karabiner+.

## Native Experience

The app launches as a normal macOS app with a Dock icon and one main window. It should not create a status bar item.

The main window uses a desktop-only layout:

- left sidebar for Setup, Coach, Studio, and Safety
- center content area for the selected workflow
- clear Liquid Glass-inspired materials using SwiftUI `.regularMaterial` / `.thinMaterial`
- neutral graphite accents, not saturated blue
- no mobile layout

## Setup Companion

The setup section shows:

- whether official Karabiner-Elements exists
- Homebrew availability
- active Karabiner profile name if a config exists
- actions to install through Homebrew, open official download, open Karabiner-Elements, back up config, and restore latest backup

All config writes require an existing `~/.config/karabiner/karabiner.json`. Every write creates a timestamped backup first.

## Shortcut Coach

Usage tracking is opt-in. It runs only while Karabiner+ is open and the user has enabled tracking.

The disclosure says Karabiner+ tracks:

- active app name
- bundle identifier when available
- active time estimate
- last seen time

The disclosure also says Karabiner+ does not track:

- keystrokes
- window titles
- document contents
- cloud data

Usage data is stored locally in `UserDefaults`. Users can start/pause tracking and delete history.

The tracker should use `NSWorkspace.shared.frontmostApplication` and accumulate time between app activation events.

## Recommendations

The app ships with static app-aware packs:

- Slack
- Browsers
- Messages
- Media
- Preview

Recommendations rank by tracked time and known app match. Applying recommendations writes `[Karabiner+] Recommended:` rules with Karabiner `frontmost_application_if` conditions.

## Shortcut Studio

V1 creates global shortcuts only:

- name
- source key
- source modifiers
- output key
- output modifiers
- plain-English preview
- warning for risky global Command shortcuts

Applying custom shortcuts writes `[Karabiner+] Custom:` rules. Applying presets must not delete custom or recommended rules.

## Out Of Scope

- menu bar item
- launch-at-login/background tracker
- direct Screen Time database reads
- keystroke logging
- raw Karabiner JSON editor
- notarized release pipeline
- App Store distribution
