import AppKit
import Foundation
import KarabinerPlusCore
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    enum Section: String, CaseIterable, Hashable, Identifiable {
        case setup = "Setup"
        case coach = "Coach"
        case studio = "Studio"
        case safety = "Safety"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .setup:
                return "switch.2"
            case .coach:
                return "chart.bar.doc.horizontal"
            case .studio:
                return "slider.horizontal.3"
            case .safety:
                return "externaldrive.badge.shield"
            }
        }
    }

    struct ShortcutDraft {
        var name = "New Shortcut"
        var sourceKey = "j"
        var sourceModifiers: Set<String> = ["command", "shift"]
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
            return "\(input) sends \(output)"
        }
    }

    @Published var selectedSection: Section? = .setup
    @Published var setupStatus: KarabinerConfigStatus?
    @Published var setupMessage = ""
    @Published var coachMessage = ""
    @Published var studioMessage = ""
    @Published var isBusy = false
    @Published var isTracking = false
    @Published var trackingError = ""
    @Published var draft = ShortcutDraft()

    let service: KarabinerConfigService
    let recommendationEngine = RecommendationEngine()
    let modifierOptions = ["command", "control", "option", "shift", "fn"]
    let keyOptions = [
        "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
        "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
        "hyphen", "equal_sign", "open_bracket", "close_bracket", "backslash",
        "semicolon", "quote", "grave_accent_and_tilde", "comma", "period", "slash",
        "tab", "spacebar", "escape", "return_or_enter",
        "left_arrow", "right_arrow", "up_arrow", "down_arrow",
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

    var usageRecords: [UsageRecord] {
        mergeUsageRecords()
    }

    var recommendedPacks: [Recommendation] {
        recommendationEngine.recommendations(for: usageEntries)
    }

    var trackingDisclosure: String {
        "Karabiner+ tracks active app name, bundle identifier when available, active time estimate, and last seen time. It does not track keystrokes, window titles, document contents, or cloud data."
    }

    func refreshStatus() {
        do {
            setupStatus = try service.readStatus()
            setupMessage = ""
        } catch {
            setupMessage = "Could not read Karabiner status: \(error.localizedDescription)"
        }
    }

    func openOfficialDownload() {
        openURL("https://karabiner-elements.pqrs.org/")
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
            setupMessage = "Backup created at \(backupURL.path)"
            refreshStatus()
        } catch {
            setupMessage = "Backup failed: \(error.localizedDescription)"
        }
    }

    func installViaHomebrew() async {
        isBusy = true
        defer { isBusy = false }

        guard homebrewAvailable else {
            setupMessage = "Homebrew was not found at /opt/homebrew/bin/brew or /usr/local/bin/brew."
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
            setupMessage = "Homebrew install failed: \(error.localizedDescription)"
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
            coachMessage = "Could not apply \(recommendation.title): \(error.localizedDescription)"
        }
    }

    func applyShortcutDraft() {
        let definition = draft.definition

        guard !definition.name.isEmpty else {
            studioMessage = "Name the shortcut before applying it."
            return
        }

        do {
            let result = try service.applyCustomShortcuts([definition])
            studioMessage = "Applied \(definition.name) to \(result.activeProfileName ?? "your active profile"). Backup: \(result.backupURL.lastPathComponent)"
            refreshStatus()
        } catch {
            studioMessage = "Could not apply shortcut: \(error.localizedDescription)"
        }
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
        case "control":
            return "Control"
        case "option":
            return "Option"
        case "shift":
            return "Shift"
        case "fn":
            return "Fn"
        default:
            return modifier.capitalized
        }
    }

    nonisolated private static func formatKey(_ key: String) -> String {
        switch key {
        case "return_or_enter":
            return "Return"
        case "spacebar":
            return "Space"
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
