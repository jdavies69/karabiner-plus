import AppKit
import Foundation
import KarabinerPlusCore
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    enum Section: String, CaseIterable, Hashable, Identifiable {
        case start = "Start"
        case setup = "Connect"
        case coach = "Coach"
        case studio = "Create"
        case safety = "Safety"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .start:
                return "sparkles"
            case .setup:
                return "checklist"
            case .coach:
                return "chart.bar.doc.horizontal"
            case .studio:
                return "plus.square.on.square"
            case .safety:
                return "externaldrive.badge.shield"
            }
        }
    }

    enum CaptureTarget: Equatable {
        case source
        case output

        var label: String {
            switch self {
            case .source:
                return "input"
            case .output:
                return "output"
            }
        }
    }

    struct ShortcutDraft {
        var name = "Caps Lock to Escape"
        var sourceKey = "caps_lock"
        var sourceModifiers: Set<String> = []
        var outputKey = "escape"
        var outputModifiers: Set<String> = []
        var appBundleIdentifier = ""
        var appName = ""

        var definition: ShortcutDefinition {
            ShortcutDefinition(
                name: name,
                sourceKey: sourceKey,
                sourceModifiers: sourceModifiers.sorted(),
                outputKey: outputKey,
                outputModifiers: outputModifiers.sorted(),
                appBundleIdentifier: appBundleIdentifier,
                appName: appName
            )
        }

        var preview: String {
            let input = AppModel.describeShortcut(modifiers: sourceModifiers.sorted(), key: sourceKey)
            let output = AppModel.describeShortcut(modifiers: outputModifiers.sorted(), key: outputKey)
            return "When you press \(input), Karabiner+ sends \(output)."
        }
    }

    struct ShortcutTemplate: Identifiable {
        let id: String
        let title: String
        let summary: String
        let draft: ShortcutDraft
    }

    struct OnboardingStep: Identifiable {
        let id: String
        let title: String
        let detail: String
        let isComplete: Bool
        let buttonTitle: String
        let section: Section
    }

    @Published var selectedSection: Section? = .start
    @Published var setupStatus: KarabinerConfigStatus?
    @Published var setupMessage = ""
    @Published var coachMessage = ""
    @Published var studioMessage = ""
    @Published var launcherMessage = ""
    @Published var isBusy = false
    @Published var isTracking = false
    @Published var trackingError = ""
    @Published var draft = ShortcutDraft()
    @Published var captureTarget: CaptureTarget?
    @Published var isFirstShortcutWizardActive = false
    @Published var pendingShortcutSummary: KarabinerApplySummary?
    @Published var pendingShortcutDefinition: ShortcutDefinition?
    @Published var launcherDrafts: [LauncherSequenceDefinition] = []
    @Published var launcherApplySummary: KarabinerApplySummary?
    @Published var savedShortcuts: [ShortcutDefinition] = []
    @Published var backupHistory: [KarabinerBackup] = []
    @Published var selectedBackupID = ""
    @Published var lastUndoBackup: KarabinerBackup?
    @Published var isCheckingForUpdates = false
    @Published var updateStatusTitle = "Not checked yet"
    @Published var updateStatusDetail = "Check GitHub to see whether a newer Karabiner+ build is available."
    @Published var updateAvailable = false
    @Published var latestUpdateURL: URL?

    let service: KarabinerConfigService
    let recommendationEngine = RecommendationEngine()
    let launcherSequenceEngine = LauncherSequenceEngine()
    let projectURL = URL(string: "https://github.com/jdavies69/karabiner-plus")!
    private var pendingLauncherDefinitions: [LauncherSequenceDefinition] = []
    let modifierOptions = ["command", "control", "option", "shift", "fn", "right_command"]
    let keyOptions = [
        "caps_lock",
        "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
        "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
        "hyphen", "equal_sign", "open_bracket", "close_bracket", "backslash",
        "semicolon", "quote", "grave_accent_and_tilde", "comma", "period", "slash",
        "tab", "spacebar", "escape", "return_or_enter", "delete_or_backspace",
        "left_arrow", "right_arrow", "up_arrow", "down_arrow",
    ]
    let shortcutTemplates: [ShortcutTemplate] = [
        ShortcutTemplate(
            id: "caps_escape",
            title: "Caps Lock to Escape",
            summary: "A low-risk classic: turn an easy-to-hit key into Escape.",
            draft: ShortcutDraft(
                name: "Caps Lock to Escape",
                sourceKey: "caps_lock",
                sourceModifiers: [],
                outputKey: "escape",
                outputModifiers: [],
                appBundleIdentifier: "",
                appName: ""
            )
        ),
        ShortcutTemplate(
            id: "right_command_h",
            title: "Right Command + H to Left Arrow",
            summary: "Use the right Command key as a navigation layer.",
            draft: ShortcutDraft(
                name: "Right Command H to Left Arrow",
                sourceKey: "h",
                sourceModifiers: ["right_command"],
                outputKey: "left_arrow",
                outputModifiers: [],
                appBundleIdentifier: "",
                appName: ""
            )
        ),
        ShortcutTemplate(
            id: "right_command_l",
            title: "Right Command + L to Right Arrow",
            summary: "Pair this with H for fast cursor movement.",
            draft: ShortcutDraft(
                name: "Right Command L to Right Arrow",
                sourceKey: "l",
                sourceModifiers: ["right_command"],
                outputKey: "right_arrow",
                outputModifiers: [],
                appBundleIdentifier: "",
                appName: ""
            )
        ),
        ShortcutTemplate(
            id: "command_shift_j",
            title: "Command + Shift + J to Escape",
            summary: "A safe test shortcut that is easy to remove later.",
            draft: ShortcutDraft(
                name: "Command Shift J to Escape",
                sourceKey: "j",
                sourceModifiers: ["command", "shift"],
                outputKey: "escape",
                outputModifiers: [],
                appBundleIdentifier: "",
                appName: ""
            )
        ),
    ]

    private let userDefaults: UserDefaults
    private let usageStoreKey = "KarabinerPlus.usageHistory"
    private var persistedUsage: [UsageRecord]
    private var sessionAccumulator = UsageAccumulator()
    private var sessionLastSeen: [String: Date] = [:]
    private var sessionMetadata: [String: UsageIdentity] = [:]
    private var timer: Timer?
    private var activationObserver: NSObjectProtocol?
    private var terminationObserver: NSObjectProtocol?
    private var shortcutCaptureMonitor: Any?

    init(
        service: KarabinerConfigService = KarabinerConfigService(),
        userDefaults: UserDefaults = .standard
    ) {
        self.service = service
        self.userDefaults = userDefaults
        self.persistedUsage = Self.loadUsageRecords(from: userDefaults, key: usageStoreKey)
        refreshStatus()
        observeTermination()
    }

    var homebrewAvailable: Bool {
        FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/brew") ||
            FileManager.default.isExecutableFile(atPath: "/usr/local/bin/brew")
    }

    var karabinerAppInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "org.pqrs.Karabiner-Elements") != nil
    }

    var hasKarabinerConfig: Bool {
        setupStatus?.configExists == true
    }

    var setupHeadline: String {
        hasKarabinerConfig ? "Ready to customize" : "Connect Karabiner first"
    }

    var setupSubheadline: String {
        if hasKarabinerConfig {
            return "Karabiner+ found your active profile and can safely write shortcuts with a backup."
        }

        return "Install and open official Karabiner-Elements once so it can create its local config."
    }

    var usageRecords: [UsageRecord] {
        mergeUsageRecords()
    }

    var recommendedPacks: [Recommendation] {
        recommendationEngine.recommendations(for: usageEntries)
    }

    var launcherSuggestions: [LauncherSequenceSuggestion] {
        launcherSequenceEngine.suggestions(for: usageEntries)
    }

    var launcherDraftsOrSuggestions: [LauncherSequenceDefinition] {
        if !launcherDrafts.isEmpty {
            return launcherDrafts
        }

        return launcherSuggestions.map(\.definition)
    }

    var onboardingSteps: [OnboardingStep] {
        [
            OnboardingStep(
                id: "karabiner-installed",
                title: "Install official Karabiner-Elements",
                detail: karabinerAppInstalled ? "Found on this Mac." : "Karabiner+ needs the official app for the keyboard engine.",
                isComplete: karabinerAppInstalled,
                buttonTitle: karabinerAppInstalled ? "Review" : "Connect",
                section: .setup
            ),
            OnboardingStep(
                id: "config-ready",
                title: "Create the Karabiner config",
                detail: hasKarabinerConfig ? "Ready to write safely." : "Open Karabiner-Elements once, then refresh.",
                isComplete: hasKarabinerConfig,
                buttonTitle: "Open Connect",
                section: .setup
            ),
            OnboardingStep(
                id: "backup-ready",
                title: "Create a recovery point",
                detail: backupHistory.isEmpty ? "Make one backup before experimenting." : "\(backupHistory.count) backup\(backupHistory.count == 1 ? "" : "s") available.",
                isComplete: !backupHistory.isEmpty,
                buttonTitle: "Open Safety",
                section: .safety
            ),
            OnboardingStep(
                id: "first-shortcut",
                title: "Save your first shortcut",
                detail: savedShortcuts.isEmpty ? "Try a safe template or capture a shortcut in Create." : "\(savedShortcuts.count) Studio shortcut\(savedShortcuts.count == 1 ? "" : "s") saved.",
                isComplete: !savedShortcuts.isEmpty,
                buttonTitle: "Open Create",
                section: .studio
            ),
        ]
    }

    var completedOnboardingCount: Int {
        onboardingSteps.filter(\.isComplete).count
    }

    var primaryOnboardingStep: OnboardingStep {
        onboardingSteps.first { !$0.isComplete } ?? onboardingSteps.last!
    }

    var trackingDisclosure: String {
        "Karabiner+ tracks active app name, bundle identifier when available, active time estimate, and last seen time. It does not track keystrokes, window titles, document contents, or cloud data."
    }

    var draftWarnings: [ShortcutWarning] {
        draft.definition.warnings
    }

    var draftCanApply: Bool {
        hasKarabinerConfig && !draft.definition.name.isEmpty && !draft.definition.isNoOp
    }

    var pendingShortcutIsCurrent: Bool {
        pendingShortcutDefinition == draft.definition
    }

    var selectedBackup: KarabinerBackup? {
        backupHistory.first { $0.id == selectedBackupID }
    }

    var canRestoreSelectedBackup: Bool {
        hasKarabinerConfig && selectedBackup != nil
    }

    var canUndoLastChange: Bool {
        hasKarabinerConfig && lastUndoBackup != nil
    }

    var appVersion: String {
        bundleString("CFBundleShortVersionString", fallback: "0.1.0")
    }

    var buildCommit: String {
        bundleString("KarabinerPlusBuildCommit", fallback: "unknown")
    }

    var buildCommitShort: String {
        shortCommit(buildCommit)
    }

    var buildBranch: String {
        bundleString("KarabinerPlusBuildBranch", fallback: "unknown")
    }

    var buildDate: String {
        bundleString("KarabinerPlusBuildDate", fallback: "unknown")
    }

    var sourcePath: String {
        bundleString("KarabinerPlusSourcePath", fallback: "")
    }

    var updateCommand: String {
        let path = sourcePath.isEmpty || sourcePath == "unknown" ? "<karabiner-plus repo>" : sourcePath
        return #"cd "\#(path)" && git pull --ff-only && ./build.sh && open "build/Karabiner+.app""#
    }

    func refreshStatus(clearSetupMessage: Bool = true) {
        do {
            setupStatus = try service.readStatus()
            if setupStatus?.configExists == true {
                savedShortcuts = try service.readCustomShortcuts()
            } else {
                savedShortcuts = []
            }
            refreshBackups()
            if clearSetupMessage {
                setupMessage = ""
            }
        } catch {
            setupMessage = "Could not read Karabiner status: \(friendlyMessage(for: error))"
        }
    }

    func openOfficialDownload() {
        openURL("https://karabiner-elements.pqrs.org/")
    }

    func openProjectOnGitHub() {
        NSWorkspace.shared.open(latestUpdateURL ?? projectURL)
    }

    func copyUpdateCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(updateCommand, forType: .string)
        updateStatusTitle = "Update command copied"
        updateStatusDetail = "Paste it into Terminal to pull the latest repo changes, rebuild, and reopen Karabiner+."
    }

    func checkForUpdates() async {
        guard !isCheckingForUpdates else { return }

        isCheckingForUpdates = true
        updateStatusTitle = "Checking GitHub..."
        updateStatusDetail = "Comparing this build with the latest main branch commit."
        updateAvailable = false
        latestUpdateURL = nil

        defer {
            isCheckingForUpdates = false
        }

        do {
            let latest = try await fetchLatestGitHubCommit()
            latestUpdateURL = latest.htmlURL

            guard buildCommit.count >= 7, buildCommit != "unknown" else {
                updateStatusTitle = "Build version is unknown"
                updateStatusDetail = "This app was built without git metadata. Latest GitHub commit is \(shortCommit(latest.sha))."
                return
            }

            if latest.sha.caseInsensitiveCompare(buildCommit) == .orderedSame {
                updateStatusTitle = "Karabiner+ is up to date"
                updateStatusDetail = "This build matches the latest GitHub main commit: \(shortCommit(latest.sha))."
                return
            }

            updateAvailable = true
            updateStatusTitle = "Update available"
            updateStatusDetail = "You are on \(buildCommitShort). GitHub main is \(shortCommit(latest.sha)): \(latest.messageLine)"
        } catch {
            updateStatusTitle = "Could not check for updates"
            updateStatusDetail = friendlyMessage(for: error)
        }
    }

    func openAccessibilitySettings() {
        openURL("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func openInputMonitoringSettings() {
        openURL("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }

    func openKarabiner() {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "org.pqrs.Karabiner-Elements") {
            NSWorkspace.shared.openApplication(at: appURL, configuration: .init(), completionHandler: nil)
            return
        }

        openURL("karabiner-elements://")
    }

    func backupConfig() {
        do {
            let backupURL = try service.backupConfig()
            refreshStatus(clearSetupMessage: false)
            setupMessage = "Backup created: \(backupURL.lastPathComponent)"
        } catch {
            setupMessage = "Backup failed: \(friendlyMessage(for: error))"
        }
    }

    func installViaHomebrew() async {
        isBusy = true
        defer { isBusy = false }

        guard homebrewAvailable else {
            setupMessage = "Homebrew is not installed. Use Download Karabiner-Elements instead, or install Homebrew first."
            return
        }

        do {
            let result = try await runProcess(
                executable: "/usr/bin/env",
                arguments: ["brew", "install", "--cask", "karabiner-elements"]
            )
            refreshStatus(clearSetupMessage: false)
            setupMessage = result.isEmpty ? "Homebrew install finished." : result
        } catch {
            setupMessage = "Homebrew install failed: \(friendlyMessage(for: error))"
        }
    }

    func startTracking() {
        guard !isTracking else { return }

        trackingError = ""
        coachMessage = ""
        isTracking = true
        sessionAccumulator = UsageAccumulator()
        sessionLastSeen = [:]
        sessionMetadata = [:]
        recordFrontmostApp(at: Date())
        startActivationObserver()
        startTimer()
    }

    func pauseTracking() {
        guard isTracking else { return }

        recordFrontmostApp(at: Date())
        stopTrackingInfrastructure()
        isTracking = false
        mergeSessionIntoPersistedUsage()
        coachMessage = "Tracking paused. Local history saved on this Mac."
    }

    func deleteHistory() {
        stopTrackingInfrastructure()
        isTracking = false
        sessionAccumulator = UsageAccumulator()
        sessionLastSeen = [:]
        sessionMetadata = [:]
        persistedUsage = []
        launcherDrafts = []
        launcherApplySummary = nil
        pendingLauncherDefinitions = []
        saveUsageRecords()
        coachMessage = "Usage history deleted from local storage."
    }

    func applyRecommendation(_ recommendation: Recommendation) {
        do {
            let result = try service.applyRecommendedPacks([recommendation.id])
            lastUndoBackup = KarabinerBackup(url: result.backupURL, modifiedAt: Date())
            coachMessage = "Applied \(recommendation.title) to \(result.activeProfileName ?? "your active profile"). Backup: \(result.backupURL.lastPathComponent)"
            refreshStatus()
        } catch {
            coachMessage = "Could not apply \(recommendation.title): \(friendlyMessage(for: error))"
        }
    }

    func refreshLauncherDraftsFromSuggestions() {
        launcherDrafts = launcherSuggestions.map(\.definition)
        launcherApplySummary = nil
        pendingLauncherDefinitions = []
        launcherMessage = launcherDrafts.isEmpty
            ? "No launcher suggestions yet. Track apps with bundle identifiers first."
            : "Launcher suggestions refreshed from local app history."
    }

    func updateLauncherSequence(for definition: LauncherSequenceDefinition, text: String) {
        if launcherDrafts.isEmpty {
            launcherDrafts = launcherSuggestions.map(\.definition)
        }

        let sequence = text
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
            .prefix(2)
            .map(String.init)

        launcherDrafts = launcherDrafts.map { existing in
            guard existing.id == definition.id else {
                return existing
            }

            return LauncherSequenceDefinition(
                appName: existing.appName,
                bundleIdentifier: existing.bundleIdentifier,
                sequence: sequence
            )
        }
        launcherApplySummary = nil
        pendingLauncherDefinitions = []
    }

    func prepareLauncherSequenceApply() {
        let definitions = launcherDraftsOrSuggestions
        guard !definitions.isEmpty else {
            launcherMessage = "No valid launcher sequences to apply yet."
            return
        }

        guard definitions.allSatisfy(\.isValid) else {
            launcherApplySummary = nil
            pendingLauncherDefinitions = []
            launcherMessage = "Keep each launcher to one or two letters or numbers, and only use apps with bundle identifiers."
            return
        }

        let validationIssues = LauncherSequenceRuleBuilder.validationIssues(for: definitions)
        guard validationIssues.isEmpty else {
            launcherApplySummary = nil
            pendingLauncherDefinitions = []
            launcherMessage = validationIssues.map(\.message).joined(separator: " ")
            return
        }

        do {
            launcherApplySummary = try service.previewLauncherSequenceApply(definitions)
            launcherDrafts = definitions
            pendingLauncherDefinitions = definitions
            launcherMessage = "Review the launcher summary, then apply when ready."
        } catch {
            launcherApplySummary = nil
            pendingLauncherDefinitions = []
            launcherMessage = "Could not preview launcher sequences: \(friendlyMessage(for: error))"
        }
    }

    func confirmLauncherSequenceApply() {
        let definitions = pendingLauncherDefinitions
        guard !definitions.isEmpty else {
            launcherMessage = "Review the launcher summary before applying."
            return
        }

        do {
            let result = try service.applyLauncherSequences(definitions)
            lastUndoBackup = KarabinerBackup(url: result.backupURL, modifiedAt: Date())
            launcherApplySummary = nil
            pendingLauncherDefinitions = []
            launcherDrafts = definitions
            launcherMessage = "Applied \(definitions.count) launcher sequence\(definitions.count == 1 ? "" : "s"). Backup: \(result.backupURL.lastPathComponent)"
            refreshStatus()
        } catch {
            launcherMessage = "Could not apply launcher sequences: \(friendlyMessage(for: error))"
        }
    }

    func cancelLauncherSequenceApply() {
        launcherApplySummary = nil
        pendingLauncherDefinitions = []
        launcherMessage = "Launcher apply cancelled. No Karabiner config changes were made."
    }

    func applyShortcutDraft() {
        prepareShortcutDraftApply()
    }

    func prepareShortcutDraftApply() {
        let definition = draft.definition

        guard !definition.name.isEmpty else {
            studioMessage = "Name the shortcut before applying it."
            return
        }

        guard !definition.isNoOp else {
            studioMessage = "This shortcut sends the same key combination it receives, so there is nothing to save."
            return
        }

        do {
            let shortcuts = replacingShortcut(definition, in: savedShortcuts)
            pendingShortcutSummary = try service.previewCustomShortcutApply(shortcuts)
            pendingShortcutDefinition = definition
            studioMessage = "Review the apply summary, then confirm when you are ready."
        } catch {
            pendingShortcutSummary = nil
            pendingShortcutDefinition = nil
            studioMessage = "Could not preview shortcut apply: \(friendlyMessage(for: error))"
        }
    }

    func confirmPendingShortcutApply() {
        guard let definition = pendingShortcutDefinition, let pendingShortcutSummary else {
            studioMessage = "Review the apply summary before writing to Karabiner."
            return
        }

        guard pendingShortcutIsCurrent else {
            studioMessage = "The shortcut changed after the summary was created. Review it again before applying."
            return
        }

        do {
            let shortcuts = replacingShortcut(definition, in: savedShortcuts)
            let result = try service.applyCustomShortcuts(shortcuts)
            lastUndoBackup = KarabinerBackup(url: result.backupURL, modifiedAt: Date())
            savedShortcuts = shortcuts
            self.pendingShortcutSummary = nil
            pendingShortcutDefinition = nil
            isFirstShortcutWizardActive = false
            studioMessage = "Saved \(definition.name) to \(pendingShortcutSummary.activeProfileName ?? result.activeProfileName ?? "your active profile"). Backup: \(result.backupURL.lastPathComponent)"
            refreshStatus()
        } catch {
            studioMessage = "Could not save shortcut: \(friendlyMessage(for: error))"
        }
    }

    func cancelPendingShortcutApply() {
        pendingShortcutSummary = nil
        pendingShortcutDefinition = nil
        studioMessage = "Apply cancelled. No Karabiner config changes were made."
    }

    func deleteShortcut(_ definition: ShortcutDefinition) {
        let shortcuts = savedShortcuts.filter {
            $0.name.localizedCaseInsensitiveCompare(definition.name) != .orderedSame
        }

        do {
            let result = try service.applyCustomShortcuts(shortcuts)
            lastUndoBackup = KarabinerBackup(url: result.backupURL, modifiedAt: Date())
            savedShortcuts = shortcuts
            studioMessage = "Removed \(definition.name) from \(result.activeProfileName ?? "your active profile"). Backup: \(result.backupURL.lastPathComponent)"
            refreshStatus()
        } catch {
            studioMessage = "Could not remove shortcut: \(friendlyMessage(for: error))"
        }
    }

    func useTemplate(_ template: ShortcutTemplate) {
        draft = template.draft
        pendingShortcutSummary = nil
        pendingShortcutDefinition = nil
        studioMessage = "Loaded template: \(template.title). Review it, then save it to Karabiner."
    }

    func resetDraft() {
        draft = ShortcutDraft()
        pendingShortcutSummary = nil
        pendingShortcutDefinition = nil
        isFirstShortcutWizardActive = false
        studioMessage = "Started a fresh shortcut."
    }

    func startFirstShortcutWizard() {
        draft = ShortcutDraft()
        pendingShortcutSummary = nil
        pendingShortcutDefinition = nil
        isFirstShortcutWizardActive = true
        studioMessage = "First shortcut wizard started. Caps Lock to Escape is loaded as a safe first shortcut."
        navigate(to: .studio)
    }

    func beginShortcutCapture(_ target: CaptureTarget) {
        stopShortcutCapture()
        captureTarget = target
        studioMessage = "Listening for \(target.label) shortcut. Press the key combination inside Karabiner+."

        shortcutCaptureMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let captured = ShortcutCapture.parse(event: event) else {
                NSSound.beep()
                return nil
            }

            Task { @MainActor in
                self?.finishShortcutCapture(captured)
            }

            return nil
        }
    }

    func cancelShortcutCapture() {
        stopShortcutCapture()
        studioMessage = "Shortcut capture cancelled."
    }

    func navigate(to section: Section) {
        selectedSection = section
    }

    func restoreSelectedBackup() {
        guard let backup = selectedBackup else {
            setupMessage = "Choose a backup before restoring."
            return
        }

        restoreBackup(backup)
    }

    func undoLastConfigWrite() {
        guard let backup = lastUndoBackup else {
            setupMessage = "There is no recent Karabiner+ change to undo in this session."
            return
        }

        restoreBackup(backup)
    }

    func openBackupDirectory() {
        NSWorkspace.shared.open(service.backupDirectoryURL)
    }

    func useFrontmostAppForDraftScope() {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            studioMessage = "Karabiner+ could not read the current frontmost app."
            return
        }

        guard let bundleIdentifier = app.bundleIdentifier, !bundleIdentifier.isEmpty else {
            studioMessage = "The current app does not expose a bundle identifier, so Karabiner+ cannot scope a shortcut to it."
            return
        }

        draft.appBundleIdentifier = bundleIdentifier
        draft.appName = app.localizedName ?? bundleIdentifier
        pendingShortcutSummary = nil
        pendingShortcutDefinition = nil
        studioMessage = "Shortcut scope set to \(draft.appName)."
    }

    func clearDraftAppScope() {
        draft.appBundleIdentifier = ""
        draft.appName = ""
        pendingShortcutSummary = nil
        pendingShortcutDefinition = nil
        studioMessage = "Shortcut scope set to everywhere."
    }

    func label(forKey key: String) -> String {
        Self.formatKey(key)
    }

    func label(forModifier modifier: String) -> String {
        Self.formatModifier(modifier)
    }

    func shortcutLabel(modifiers: Set<String>, key: String) -> String {
        Self.describeShortcut(modifiers: modifiers.sorted(), key: key)
    }

    func shortcutLabel(modifiers: [String], key: String) -> String {
        Self.describeShortcut(modifiers: modifiers, key: key)
    }

    func preview(for definition: ShortcutDefinition) -> String {
        let input = shortcutLabel(modifiers: definition.sourceModifiers, key: definition.sourceKey)
        let output = shortcutLabel(modifiers: definition.outputModifiers, key: definition.outputKey)
        return "\(input) -> \(output)"
    }

    func scopeDescription(for definition: ShortcutDefinition) -> String {
        guard definition.isAppSpecific else {
            return "Everywhere"
        }

        if !definition.appName.isEmpty {
            return "Only in \(definition.appName) (\(definition.appBundleIdentifier))"
        }

        return "Only in \(definition.appBundleIdentifier)"
    }

    var draftScopeDescription: String {
        scopeDescription(for: draft.definition)
    }

    func reason(for recommendation: Recommendation) -> String {
        let matchedRecords = usageRecords.filter { record in
            recommendation.matches(appName: record.name, bundleIdentifier: record.bundleIdentifier)
        }
        let seconds = matchedRecords.reduce(0) { $0 + $1.seconds }

        guard seconds > 0 else {
            return "Recommended from your local app usage."
        }

        let appNames = matchedRecords
            .sorted { $0.seconds > $1.seconds }
            .prefix(2)
            .map(\.name)
            .joined(separator: ", ")

        return "Based on \(formatDuration(seconds)) in \(appNames)."
    }

    func containsModifier(_ modifier: String, in set: Set<String>) -> Bool {
        set.contains(modifier)
    }

    func setModifier(_ modifier: String, enabled: Bool, in set: inout Set<String>) {
        if enabled {
            set.insert(modifier)
        } else {
            set.remove(modifier)
        }
    }

    func formatDuration(_ seconds: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 3_600 ? [.hour, .minute] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = [.dropLeading, .dropMiddle]
        return formatter.string(from: TimeInterval(seconds)) ?? "\(seconds)s"
    }

    func formatLastSeen(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    func formatLauncherReason(for definition: LauncherSequenceDefinition) -> String {
        guard let record = usageRecords.first(where: { $0.bundleIdentifier.caseInsensitiveCompare(definition.bundleIdentifier) == .orderedSame }) else {
            return definition.bundleIdentifier
        }

        return "\(formatDuration(record.seconds)) tracked · \(definition.bundleIdentifier)"
    }

    func formatBackup(_ backup: KarabinerBackup) -> String {
        if let modifiedAt = backup.modifiedAt {
            return "\(backup.name) · \(modifiedAt.formatted(date: .abbreviated, time: .shortened))"
        }

        return backup.name
    }

    private var usageEntries: [UsageEntry] {
        usageRecords.map {
            UsageEntry(
                app: TrackedApp(name: $0.name, bundleIdentifier: $0.bundleIdentifier),
                seconds: $0.seconds
            )
        }
    }

    private func finishShortcutCapture(_ captured: CapturedShortcut) {
        guard let captureTarget else { return }

        switch captureTarget {
        case .source:
            draft.sourceKey = captured.key
            draft.sourceModifiers = Set(captured.modifiers)
        case .output:
            draft.outputKey = captured.key
            draft.outputModifiers = Set(captured.modifiers)
        }

        pendingShortcutSummary = nil
        pendingShortcutDefinition = nil
        studioMessage = "Captured \(captureTarget.label): \(shortcutLabel(modifiers: captured.modifiers, key: captured.key))."
        stopShortcutCapture()
    }

    private func stopShortcutCapture() {
        if let shortcutCaptureMonitor {
            NSEvent.removeMonitor(shortcutCaptureMonitor)
            self.shortcutCaptureMonitor = nil
        }

        captureTarget = nil
    }

    private func fetchLatestGitHubCommit() async throws -> GitHubCommit {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/jdavies69/karabiner-plus/commits/main")!)
        request.setValue("KarabinerPlus/\(appVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UpdateError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw UpdateError.httpStatus(httpResponse.statusCode)
        }

        let payload = try JSONDecoder().decode(GitHubCommitResponse.self, from: data)
        return GitHubCommit(
            sha: payload.sha,
            htmlURL: URL(string: payload.htmlURL) ?? projectURL,
            messageLine: payload.commit.message.components(separatedBy: .newlines).first ?? "Latest update"
        )
    }

    private func replacingShortcut(_ definition: ShortcutDefinition, in shortcuts: [ShortcutDefinition]) -> [ShortcutDefinition] {
        let filtered = shortcuts.filter {
            $0.name.localizedCaseInsensitiveCompare(definition.name) != .orderedSame
        }

        return filtered + [definition]
    }

    private func refreshBackups() {
        do {
            backupHistory = try service.listBackups()
            let ids = Set(backupHistory.map(\.id))

            if selectedBackupID.isEmpty || !ids.contains(selectedBackupID) {
                selectedBackupID = backupHistory.first?.id ?? ""
            }

            if let lastUndoBackup, !ids.contains(lastUndoBackup.id) {
                self.lastUndoBackup = nil
            }
        } catch {
            backupHistory = []
            selectedBackupID = ""
            lastUndoBackup = nil
        }
    }

    private func restoreBackup(_ backup: KarabinerBackup) {
        do {
            let result = try service.restoreBackup(backup)
            lastUndoBackup = KarabinerBackup(url: result.preRestoreBackupURL, modifiedAt: Date())
            refreshStatus(clearSetupMessage: false)
            setupMessage = "Restored \(backup.name). Pre-restore backup: \(result.preRestoreBackupURL.lastPathComponent)"
        } catch {
            setupMessage = "Restore failed: \(friendlyMessage(for: error))"
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        if let serviceError = error as? KarabinerConfigServiceError {
            switch serviceError {
            case .configNotFound:
                return "Karabiner config was not found. Open Karabiner-Elements once, then refresh."
            case .invalidConfig:
                return "Karabiner config could not be read. Create a backup before editing it manually."
            case let .conflicts(conflicts):
                let details = conflicts
                    .flatMap(\.ruleDescriptions)
                    .prefix(3)
                    .joined(separator: ", ")
                return details.isEmpty
                    ? "A shortcut conflict was found."
                    : "A shortcut conflict was found with \(details)."
            case let .invalidLauncherSequences(issues):
                return issues.first?.message ?? "Launcher sequences must be unique and use one or two letters or numbers."
            }
        }

        return error.localizedDescription
    }

    private func startActivationObserver() {
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.recordFrontmostApp(at: Date())
            }
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.recordFrontmostApp(at: Date())
            }
        }
    }

    private func stopTrackingInfrastructure() {
        timer?.invalidate()
        timer = nil

        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
            self.activationObserver = nil
        }
    }

    private func observeTermination() {
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                if self.isTracking {
                    self.recordFrontmostApp(at: Date())
                    self.mergeSessionIntoPersistedUsage()
                }
            }
        }
    }

    private func recordFrontmostApp(at timestamp: Date) {
        guard isTracking else { return }

        guard let app = NSWorkspace.shared.frontmostApplication else {
            trackingError = "Karabiner+ could not read the current frontmost app."
            return
        }

        let name = app.localizedName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = (name?.isEmpty == false ? name! : "Unknown App")
        let bundleIdentifier = app.bundleIdentifier ?? ""
        let trackedApp = TrackedApp(name: resolvedName, bundleIdentifier: bundleIdentifier)
        let key = Self.usageKey(name: resolvedName, bundleIdentifier: bundleIdentifier)

        sessionAccumulator.record(app: trackedApp, at: timestamp)
        sessionLastSeen[key] = timestamp
        sessionMetadata[key] = UsageIdentity(name: resolvedName, bundleIdentifier: bundleIdentifier)
    }

    private func mergeSessionIntoPersistedUsage() {
        persistedUsage = mergeUsageRecords()
        saveUsageRecords()
        sessionAccumulator = UsageAccumulator()
        sessionLastSeen = [:]
        sessionMetadata = [:]
    }

    private func mergeUsageRecords() -> [UsageRecord] {
        var recordsByKey = Dictionary(uniqueKeysWithValues: persistedUsage.map { ($0.id, $0) })

        for entry in sessionAccumulator.entries {
            let key = Self.usageKey(name: entry.app.name, bundleIdentifier: entry.app.bundleIdentifier)
            let lastSeen = sessionLastSeen[key] ?? Date()
            let current = recordsByKey[key]

            recordsByKey[key] = UsageRecord(
                name: current?.name ?? entry.app.name,
                bundleIdentifier: current?.bundleIdentifier ?? entry.app.bundleIdentifier,
                seconds: (current?.seconds ?? 0) + entry.seconds,
                lastSeen: max(current?.lastSeen ?? .distantPast, lastSeen)
            )
        }

        for (key, identity) in sessionMetadata where recordsByKey[key] == nil {
            recordsByKey[key] = UsageRecord(
                name: identity.name,
                bundleIdentifier: identity.bundleIdentifier,
                seconds: 0,
                lastSeen: sessionLastSeen[key] ?? .now
            )
        }

        return recordsByKey.values.sorted { left, right in
            if left.seconds != right.seconds {
                return left.seconds > right.seconds
            }

            return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
        }
    }

    private func saveUsageRecords() {
        do {
            let data = try JSONEncoder().encode(persistedUsage)
            userDefaults.set(data, forKey: usageStoreKey)
        } catch {
            coachMessage = "Could not save usage history: \(error.localizedDescription)"
        }
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    private func bundleString(_ key: String, fallback: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? fallback
    }

    private func shortCommit(_ commit: String) -> String {
        guard commit.count > 7 else {
            return commit
        }

        return String(commit.prefix(7))
    }

    private func runProcess(executable: String, arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            process.terminationHandler = { process in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(decoding: outputData + errorData, as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: ProcessError.exitStatus(process.terminationStatus, output))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func loadUsageRecords(from userDefaults: UserDefaults, key: String) -> [UsageRecord] {
        guard let data = userDefaults.data(forKey: key) else {
            return []
        }

        do {
            return try JSONDecoder().decode([UsageRecord].self, from: data)
        } catch {
            return []
        }
    }

    nonisolated static func usageKey(name: String, bundleIdentifier: String) -> String {
        if !bundleIdentifier.isEmpty {
            return bundleIdentifier.lowercased()
        }

        return "name:\(name.lowercased())"
    }

    nonisolated private static func describeShortcut(modifiers: [String], key: String) -> String {
        let pieces = modifiers.map(formatModifier) + [formatKey(key)]
        return pieces.joined(separator: "-")
    }

    nonisolated private static func formatModifier(_ modifier: String) -> String {
        switch modifier {
        case "command":
            return "Command"
        case "left_command":
            return "Left Command"
        case "right_command":
            return "Right Command"
        case "control":
            return "Control"
        case "left_control":
            return "Left Control"
        case "right_control":
            return "Right Control"
        case "option":
            return "Option"
        case "left_option":
            return "Left Option"
        case "right_option":
            return "Right Option"
        case "shift":
            return "Shift"
        case "left_shift":
            return "Left Shift"
        case "right_shift":
            return "Right Shift"
        case "fn":
            return "Fn"
        default:
            return modifier.capitalized
        }
    }

    nonisolated private static func formatKey(_ key: String) -> String {
        switch key {
        case "caps_lock":
            return "Caps Lock"
        case "return_or_enter":
            return "Return"
        case "spacebar":
            return "Space"
        case "delete_or_backspace":
            return "Delete"
        case "left_arrow":
            return "Left Arrow"
        case "right_arrow":
            return "Right Arrow"
        case "up_arrow":
            return "Up Arrow"
        case "down_arrow":
            return "Down Arrow"
        case "equal_sign":
            return "="
        case "hyphen":
            return "-"
        default:
            return key.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

}

struct UsageRecord: Codable, Identifiable {
    let name: String
    let bundleIdentifier: String
    let seconds: Int
    let lastSeen: Date

    var id: String {
        AppModel.usageKey(name: name, bundleIdentifier: bundleIdentifier)
    }
}

private struct UsageIdentity {
    let name: String
    let bundleIdentifier: String
}

private struct GitHubCommit {
    let sha: String
    let htmlURL: URL
    let messageLine: String
}

private struct GitHubCommitResponse: Decodable {
    let sha: String
    let htmlURL: String
    let commit: Commit

    enum CodingKeys: String, CodingKey {
        case sha
        case htmlURL = "html_url"
        case commit
    }

    struct Commit: Decodable {
        let message: String
    }
}

private enum UpdateError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "GitHub returned an unreadable response."
        case let .httpStatus(status):
            return "GitHub update check failed with status \(status)."
        }
    }
}

private enum ProcessError: LocalizedError {
    case exitStatus(Int32, String)

    var errorDescription: String? {
        switch self {
        case let .exitStatus(status, output) where output.isEmpty:
            return "Process exited with status \(status)."
        case let .exitStatus(status, output):
            return "Process exited with status \(status): \(output)"
        }
    }
}
