# Usage Coach Shortcut Studio Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add opt-in local usage tracking, app-based shortcut recommendations, and a safe global custom shortcut creator to Karabiner Starter.

**Architecture:** Keep Karabiner writes in `src/core` and `src/server.js`; keep usage accumulation in the browser so tracking stops when the page closes; keep recommendation and shortcut rule generation in pure core modules with tests. Update the desktop UI to expose Setup Companion, Shortcut Coach, Shortcut Studio, and Safety panels without adding a mobile layout.

**Tech Stack:** Node.js 20, native `node:test`, browser JavaScript, static HTML/CSS, macOS shell helpers for frontmost app lookup.

## Global Constraints

- macOS only.
- Tracking runs only while the Karabiner Starter page is open and after the user presses Start.
- Tracking stores only app name, bundle id when available, active time estimate, and last seen timestamp.
- Tracking does not store keystrokes, window titles, document contents, or cloud data.
- Usage history is stored in browser `localStorage` and can be deleted from the UI.
- All Karabiner config writes require an existing Karabiner config file.
- Every Karabiner config write creates a backup first.
- Preset apply must not delete custom or recommended Karabiner Starter rules.
- Custom Shortcut V1 creates global shortcuts only.
- Avoid raw Karabiner JSON editing in the UI.
- Keep the app desktop-only; no mobile layout.

---

### Task 1: Category-Aware Rule Ownership

**Files:**
- Modify: `src/core/config.js`
- Modify: `test/config.test.js`

**Interfaces:**
- Produces: `STARTER_PRESET_PREFIX`, `STARTER_CUSTOM_PREFIX`, `STARTER_RECOMMENDED_PREFIX`
- Produces: `mergeOwnedRules(config, newRules, ownedPrefix)`
- Updates: `mergeStarterRules(config, starterRules)` to replace only preset-owned rules

- [ ] Write failing tests proving preset merge preserves `[Karabiner Starter] Custom:` and `[Karabiner Starter] Recommended:` rules.
- [ ] Run `npm test -- test/config.test.js` and confirm the new test fails because current merge removes every starter-owned rule.
- [ ] Implement category-aware ownership prefixes and `mergeOwnedRules`.
- [ ] Update `collectExistingTriggers` so all Karabiner Starter owned rules are ignored when checking conflicts against user-owned rules.
- [ ] Run `npm test -- test/config.test.js` and confirm it passes.
- [ ] Commit this task.

### Task 2: Custom Shortcut Rule Builder

**Files:**
- Create: `src/core/custom-shortcuts.js`
- Create: `test/custom-shortcuts.test.js`
- Modify: `src/core/apply.js`

**Interfaces:**
- Produces: `keyCatalog`
- Produces: `modifierCatalog`
- Produces: `validateCustomShortcut(definition)`
- Produces: `buildCustomShortcutRule(definition)`
- Produces: `planCustomShortcutApplication(config, definitions)`

- [ ] Write failing tests for valid custom shortcut rule generation, required field validation, risky shortcut warnings, and conflict blocking.
- [ ] Run `npm test -- test/custom-shortcuts.test.js` and confirm failures are due to missing module/functions.
- [ ] Implement key/modifier catalogs, validation, plain-English summaries, risky shortcut detection, and rule generation.
- [ ] Implement `planCustomShortcutApplication` using existing conflict detection and category-aware merge.
- [ ] Run `npm test -- test/custom-shortcuts.test.js test/apply.test.js`.
- [ ] Commit this task.

### Task 3: Recommendations And Usage Core

**Files:**
- Create: `src/core/recommendations.js`
- Create: `test/recommendations.test.js`

**Interfaces:**
- Produces: `recommendationPacks`
- Produces: `normalizeUsageEntries(entries)`
- Produces: `recommendPacksForUsage(entries)`
- Produces: `rulesForRecommendationIds(ids)`

- [ ] Write failing tests for ranking packs from Slack/browser/media usage, ignoring zero-time entries, and generating recommended rules with app conditions.
- [ ] Run `npm test -- test/recommendations.test.js` and confirm missing module/function failures.
- [ ] Implement the static pack catalog, app matchers, ranking, and recommendation rule generation.
- [ ] Run `npm test -- test/recommendations.test.js`.
- [ ] Commit this task.

### Task 4: Server API

**Files:**
- Modify: `src/server.js`
- Create: `src/core/frontmost-app.js`
- Modify: `test/server.test.js`

**Interfaces:**
- Adds: `GET /api/frontmost-app`
- Adds: `POST /api/apply-custom`
- Adds: `GET /api/recommendations`
- Adds: `POST /api/apply-recommendations`
- Produces: `getFrontmostApp({ runner })`

- [ ] Write failing server tests for injected frontmost provider, custom apply conflicts/success, recommendation list, and recommendation apply.
- [ ] Run `npm test -- test/server.test.js` and confirm the new endpoint tests fail.
- [ ] Implement frontmost-app provider with Swift first and AppleScript fallback.
- [ ] Add server routes that validate input, require existing config before writes, back up first, and return conflicts/warnings as JSON.
- [ ] Run `npm test -- test/server.test.js test/custom-shortcuts.test.js test/recommendations.test.js`.
- [ ] Commit this task.

### Task 5: Desktop UI

**Files:**
- Modify: `public/index.html`
- Modify: `public/app.js`
- Modify: `public/styles.css`

**Interfaces:**
- Consumes: `/api/frontmost-app`, `/api/recommendations`, `/api/apply-recommendations`, `/api/apply-custom`
- Stores: `karabinerStarterUsageV1` in `localStorage`

- [ ] Add a Shortcut Coach panel with the required disclosure copy, Start/Pause, Delete History, top apps, and recommendations.
- [ ] Add a Shortcut Studio panel with name, source key, source modifiers, output key, output modifiers, preview, warning text, and apply button.
- [ ] Update app state and render logic without introducing mobile-specific layout.
- [ ] Style the new panels in the existing clear Liquid Glass direction.
- [ ] Run `npm test`.
- [ ] Commit this task.

### Task 6: Docs And Verification

**Files:**
- Modify: `README.md`
- Modify: `docs/usage.md`
- Modify: `docs/superpowers/specs/2026-06-25-karabiner-starter-design.md`

**Interfaces:**
- Documents the tracker disclosure, local-only behavior, custom shortcut limits, recommendations, and backup safety.

- [ ] Update docs with the new usage tracking, recommendation, and Shortcut Studio workflows.
- [ ] Run `npm test`.
- [ ] Run `npm run lint`.
- [ ] Start the local server and verify the desktop UI in a browser at the local URL.
- [ ] Commit docs and any verification fixes.
- [ ] Push the feature branch to GitHub.
