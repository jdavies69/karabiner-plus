# Usage Coach And Shortcut Studio Design

## Goal

Karabiner Starter should become a local Mac shortcut coach: it helps a trusted user set up Karabiner, optionally learn which apps they actively use while the setup page is open, recommend useful shortcut packs, and create safe custom shortcuts without writing Karabiner JSON.

## Product Positioning

The app is not a full Karabiner replacement. It owns the friendly layer above Karabiner:

- Setup Companion: install/open official Karabiner, check local status, back up and restore config.
- Shortcut Studio: create constrained custom rules with guardrails, plain-English previews, conflict checks, and backup-before-apply.
- Shortcut Coach: track app usage only while the app is open and the user explicitly starts tracking, then recommend shortcut packs for heavily used apps.

The design principle is: make the 20 percent of keyboard customization that normal smart Mac users actually want feel safe, obvious, and beautiful.

## Usage Tracking V1

Usage tracking is opt-in and only runs while the Karabiner Starter page is open. The UI must disclose exactly what is collected before the user starts tracking:

- active app name
- bundle identifier when available
- active time estimate
- last seen time

The UI must also say what is not collected:

- no keystrokes
- no window titles
- no document contents
- no cloud sync

Storage is local to the browser via `localStorage`. The user can pause tracking and delete usage history from the UI. The server exposes a frontmost-app endpoint that returns the currently active app. The browser controls the sampling interval and accumulation, which prevents a hidden background tracker from running after the page is closed.

The preferred source is macOS `NSWorkspace.frontmostApplication` through a Swift helper when Swift is available. A fallback AppleScript provider may be used for development environments where Swift is unavailable, but any failure should be shown as a friendly tracking error rather than blocking the rest of the app.

## Recommendations

Recommendations are generated from local usage totals and a static pack catalog. A pack has:

- id
- title
- summary
- app matchers by bundle id and name
- shortcut rules
- confidence reason
- risk level

Initial app-aware packs:

- Slack: quick navigation and composition helpers.
- Browsers: tab navigation and address bar helpers for Safari, Arc, Chrome, and Firefox.
- Messages: conversation navigation helpers.
- YouTube/media: media key helpers.
- Preview: document navigation helpers.

Recommendations are ranked by tracked seconds, then by known app-pack fit. The UI should show why a recommendation appeared, the app it relates to, and a one-click apply path.

## Shortcut Studio V1

Shortcut Studio creates global custom shortcuts only. App-specific custom shortcuts can come later after the global flow is proven.

The user can choose:

- a rule name
- a source key
- source modifiers
- an output key
- output modifiers

The app shows a plain-English preview before applying. The server validates the definition, builds a Karabiner complex modification rule, checks conflicts against existing non-owned rules and selected new rules, creates a backup, and writes the config atomically.

Custom rule descriptions use `[Karabiner Starter] Custom:`. Recommendation rules use `[Karabiner Starter] Recommended:`. Preset rules keep their existing `[Karabiner Starter]` descriptions but the merge logic must become category-aware so applying presets does not delete custom or recommended rules.

## Safety

All config writes require an existing Karabiner config file. Every write creates a timestamped backup first. Conflict checks must cover custom, preset, and recommendation rules before writes.

The UI warns when a custom source shortcut uses common risky global Mac shortcuts, including Command-Q, Command-W, Command-Tab, Command-Space, Command-C, Command-V, Command-X, Command-Z, and Command-S.

## Interface Direction

The app remains macOS desktop-only. No mobile layout is required. The interface should feel like a clear Liquid Glass Mac utility:

- transparent, restrained panels
- neutral glass instead of saturated blue
- sidebar or segmented workspace organization
- dense but legible controls
- visible backup, conflict, and restore affordances
- no marketing page

The first screen should remain the actual app workspace.

## Out Of Scope

- background login item tracking
- direct Screen Time database reads
- keystroke logging
- window title or document capture
- raw arbitrary Karabiner JSON editing
- packaged/notarized Mac app
- cloud backend
