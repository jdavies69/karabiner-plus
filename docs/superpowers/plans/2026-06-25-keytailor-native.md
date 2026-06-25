# KeyTailor Native Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native Swift macOS app shell named KeyTailor that covers setup, opt-in active-app usage tracking, recommendations, and safe global shortcut creation for Karabiner-Elements.

**Architecture:** Add a Swift package-style source tree with testable `KeyTailorCore` logic and a SwiftUI/AppKit `KeyTailorApp`. Keep the existing Node prototype intact while shifting README/docs and build output to the native app.

**Tech Stack:** Swift 6.3 command-line tools, SwiftUI, AppKit, a plain Swift `KeyTailorCoreCheck` executable for local verification, existing Node tests for the legacy prototype.

## Global Constraints

- Native app name is KeyTailor.
- The app is a windowed macOS app with Dock icon; no menu bar status item.
- macOS only.
- Tracking runs only while KeyTailor is open and after the user starts it.
- Tracking stores only app name, bundle id when available, active time estimate, and last seen timestamp.
- Tracking does not store keystrokes, window titles, document contents, or cloud data.
- Usage history is local and can be deleted from the UI.
- All Karabiner config writes require an existing Karabiner config file.
- Every Karabiner config write creates a backup first.
- Preset apply must not delete custom or recommended Karabiner Starter rules.
- Custom Shortcut V1 creates global shortcuts only.
- Avoid raw Karabiner JSON editing in the UI.
- Keep the app desktop-only; no mobile layout.

---

### Task 1: Swift Core Models And Tests

**Files:**
- Create: `Package.swift`
- Create: `Sources/KeyTailorCore/ShortcutDefinition.swift`
- Create: `Sources/KeyTailorCore/UsageTracker.swift`
- Create: `Sources/KeyTailorCore/RecommendationEngine.swift`
- Create: `Sources/KeyTailorCoreCheck/main.swift`

**Interfaces:**
- Produces: `ShortcutDefinition`
- Produces: `ShortcutWarning`
- Produces: `ShortcutRuleBuilder.buildCustomRule(_:)`
- Produces: `UsageEntry`
- Produces: `UsageAccumulator.record(app:at:)`
- Produces: `RecommendationEngine.recommendations(for:)`

- [ ] Write failing Swift check-runner coverage for custom shortcut JSON generation, risky Command-Q warning, usage accumulation, and Slack/browser recommendation ranking.
- [ ] Run `swift run KeyTailorCoreCheck` and confirm missing type/function failures.
- [ ] Implement the minimal Swift core models and engines.
- [ ] Run `swift run KeyTailorCoreCheck` and confirm it passes.
- [ ] Commit this task.

### Task 2: Karabiner Config Service

**Files:**
- Create: `Sources/KeyTailorCore/KarabinerConfigService.swift`
- Modify: `Sources/KeyTailorCoreCheck/main.swift`

**Interfaces:**
- Produces: `KarabinerConfigService.readStatus()`
- Produces: `KarabinerConfigService.backupConfig()`
- Produces: `KarabinerConfigService.applyCustomShortcuts(_:)`
- Produces: `KarabinerConfigService.applyRecommendedPacks(_:)`

- [ ] Write failing Swift check-runner coverage that applying custom shortcuts preserves recommended rules and creates a backup in a temporary config directory.
- [ ] Run `swift run KeyTailorCoreCheck` and confirm the new check fails due to missing service behavior.
- [ ] Implement file read/write, backup creation, category-aware starter rule merging, and basic conflict detection.
- [ ] Run `swift run KeyTailorCoreCheck`.
- [ ] Commit this task.

### Task 3: Native SwiftUI App

**Files:**
- Create: `Sources/KeyTailorApp/KeyTailorApp.swift`
- Create: `Sources/KeyTailorApp/AppModel.swift`
- Create: `Sources/KeyTailorApp/ContentView.swift`
- Create: `Sources/KeyTailorApp/SetupView.swift`
- Create: `Sources/KeyTailorApp/CoachView.swift`
- Create: `Sources/KeyTailorApp/StudioView.swift`
- Create: `Sources/KeyTailorApp/SafetyView.swift`

**Interfaces:**
- Consumes: `KeyTailorCore`
- Produces: a normal SwiftUI windowed app with Setup, Coach, Studio, and Safety sections.

- [ ] Create the SwiftUI app shell using `NavigationSplitView`.
- [ ] Add Setup actions for refresh, install via Homebrew, open download page, open Karabiner, and backup.
- [ ] Add Coach disclosure, Start/Pause tracking, Delete History, top apps, and recommendations.
- [ ] Add Studio form with shortcut preview, warnings, save/apply action.
- [ ] Keep the visual direction native, clear, neutral, and desktop-only.
- [ ] Run `swift build`.
- [ ] Commit this task.

### Task 4: App Bundle Build

**Files:**
- Create: `build.sh`
- Create: `Sources/KeyTailorApp/Info.plist`
- Modify: `.gitignore`

**Interfaces:**
- Produces: `build/KeyTailor.app`

- [ ] Add a build script that compiles the Swift app and creates a launchable `.app` bundle.
- [ ] Set `CFBundleName`, `CFBundleDisplayName`, `CFBundleIdentifier`, `CFBundleExecutable`, `CFBundlePackageType`, `LSMinimumSystemVersion`, and `NSPrincipalClass`.
- [ ] Ensure the app is not `LSUIElement`; it should have a Dock icon.
- [ ] Run `./build.sh`.
- [ ] Run `open build/KeyTailor.app` for a smoke launch if possible.
- [ ] Commit this task.

### Task 5: Docs, Legacy Positioning, And Final Verification

**Files:**
- Modify: `README.md`
- Modify: `docs/usage.md`
- Modify: `package.json`
- Modify: `docs/superpowers/specs/2026-06-25-karabiner-starter-design.md`

**Interfaces:**
- Documents KeyTailor as the primary app and the Node browser UI as a legacy prototype/fallback.

- [ ] Update docs with native app build/run steps, privacy disclosure, recommendations, and Shortcut Studio behavior.
- [ ] Add npm scripts if useful for checking the legacy prototype and Swift tests together.
- [ ] Run `swift run KeyTailorCoreCheck`.
- [ ] Run `./build.sh`.
- [ ] Run `npm test`.
- [ ] Run `npm run lint`.
- [ ] Merge to `main` and push to GitHub after verification.
