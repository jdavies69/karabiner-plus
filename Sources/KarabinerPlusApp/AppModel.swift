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

    struct ShortcutDraft {
        var name = "Caps Lock to Escape"
        var sourceKey = "caps_lock"
        var sourceModifiers: Set<String> = []
        var outputKey = "escape"
        var outputModifiers: Set<String> = []

        var definition: ShortcutDefinition {
            ShortcutDefinition(
                name: name,
                sourceKey: sourceKey,
                sourceModifiers: sourceModifiers.sorted(),
                outputKey: outputKey,
                outputModifiers: outputModifiers.sorted()
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

    @Published var selectedSection: Section? = .start
    @Published var setupStatus: KarabinerConfigStatus?
    @Published var setupMessage = ""
    @Published var coachMessage = ""
    @Published var studioMessage = ""
    @Published var isBusy = false
    @Published var isTracking = false
    @Published var trackingError = ""
    @Published var draft = ShortcutDraft()
    @Published var savedShortcuts: [ShortcutDefinition] = []

    let service: KarabinerConfigService
    let recommendationEngine = RecommendationEngine()
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
                outputModifiers: []
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
                outputModifiers: []
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
                outputModifiers: []
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
                outputModifiers: []
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

    var trackingDisclosure: String {
        "Karabiner+ tracks active app name, bundle identifier when available, active time estimate, and last seen time. It does not track keystrokes, window titles, document contents, or cloud data."
    }

    var draftWarnings: [ShortcutWarning] {
        draft.definition.warnings
    }

    var draftCanApply: Bool {
        hasKarabinerConfig && !draft.definition.name.isEmpty && !draft.definition.isNoOp
    }

    func refreshStatus() {
        do {
            setupStatus = try service.readStatus()
            if setupStatus?.configExists == true {
                savedShortcuts = try service.readCustomShortcuts()
            } else {
                savedShortcuts = []
            }
            setupMessage = ""
        } catch {
            setupMessage = "Could not read Karabiner status: \(friendlyMessage(for: error))"
        }
    }

    func openOfficialDownload() {
        openURL("https://karabiner-elements.pqrs.org/")
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
            setupMessage = "Backup created: \(backupURL.lastPathComponent)"
            refreshStatus()
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
            setupMessage = result.isEmpty ? "Homebrew install finished." : result
            refreshStatus()
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
        saveUsageRecords()
        coachMessage = "Usage history deleted from local storage."
    }

    func applyRecommendation(_ recommendation: Recommendation) {
        do {
            let result = try service.applyRecommendedPacks([recommendation.id])
            coachMessage = "Applied \(recommendation.title) to \(result.activeProfileName ?? "your active profile"). Backup: \(result.backupURL.lastPathComponent)"
            refreshStatus()
        } catch {
            coachMessage = "Could not apply \(recommendation.title): \(friendlyMessage(for: error))"
        }
    }

    func applyShortcutDraft() {
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
            let result = try service.applyCustomShortcuts(shortcuts)
            savedShortcuts = shortcuts
            studioMessage = "Saved \(definition.name) to \(result.activeProfileName ?? "your active profile"). Backup: \(result.backupURL.lastPathComponent)"
            refreshStatus()
        } catch {
            studioMessage = "Could not save shortcut: \(friendlyMessage(for: error))"
        }
    }

    func deleteShortcut(_ definition: ShortcutDefinition) {
        let shortcuts = savedShortcuts.filter {
            $0.name.localizedCaseInsensitiveCompare(definition.name) != .orderedSame
        }

        do {
            let result = try service.applyCustomShortcuts(shortcuts)
            savedShortcuts = shortcuts
            studioMessage = "Removed \(definition.name) from \(result.activeProfileName ?? "your active profile"). Backup: \(result.backupURL.lastPathComponent)"
            refreshStatus()
        } catch {
            studioMessage = "Could not remove shortcut: \(friendlyMessage(for: error))"
        }
    }

    func useTemplate(_ template: ShortcutTemplate) {
        draft = template.draft
        studioMessage = "Loaded template: \(template.title). Review it, then save it to Karabiner."
    }

    func resetDraft() {
        draft = ShortcutDraft()
        studioMessage = "Started a fresh shortcut."
    }

    func navigate(to section: Section) {
        selectedSection = section
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

    private var usageEntries: [UsageEntry] {
        usageRecords.map {
            UsageEntry(
                app: TrackedApp(name: $0.name, bundleIdentifier: $0.bundleIdentifier),
                seconds: $0.seconds
            )
        }
    }

    private func replacingShortcut(_ definition: ShortcutDefinition, in shortcuts: [ShortcutDefinition]) -> [ShortcutDefinition] {
        let filtered = shortcuts.filter {
            $0.name.localizedCaseInsensitiveCompare(definition.name) != .orderedSame
        }

        return filtered + [definition]
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
