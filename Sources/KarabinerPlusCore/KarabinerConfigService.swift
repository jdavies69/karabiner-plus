import Foundation

public struct KarabinerConfigStatus: Equatable, Sendable {
    public let configExists: Bool
    public let activeProfileName: String?

    public init(configExists: Bool, activeProfileName: String?) {
        self.configExists = configExists
        self.activeProfileName = activeProfileName
    }
}

public struct KarabinerApplyResult: Equatable, Sendable {
    public let backupURL: URL
    public let activeProfileName: String?

    public init(backupURL: URL, activeProfileName: String?) {
        self.backupURL = backupURL
        self.activeProfileName = activeProfileName
    }
}

public struct KarabinerRuleConflict: Equatable, Sendable {
    public let trigger: String
    public let ruleDescriptions: [String]

    public init(trigger: String, ruleDescriptions: [String]) {
        self.trigger = trigger
        self.ruleDescriptions = ruleDescriptions
    }
}

public enum KarabinerConfigServiceError: Error, Equatable, Sendable {
    case configNotFound
    case invalidConfig
    case conflicts([KarabinerRuleConflict])
}

public struct KarabinerConfigService: Sendable {
    public let configURL: URL
    public let backupDirectoryURL: URL
    private let now: @Sendable () -> Date

    public init(
        configURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/karabiner/karabiner.json"),
        backupDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/karabiner/backups", isDirectory: true),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.configURL = configURL
        self.backupDirectoryURL = backupDirectoryURL
        self.now = now
    }

    public func readStatus() throws -> KarabinerConfigStatus {
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            return KarabinerConfigStatus(configExists: false, activeProfileName: nil)
        }

        let config = try readConfig()
        return KarabinerConfigStatus(
            configExists: true,
            activeProfileName: selectedProfile(in: config)?["name"] as? String
        )
    }

    @discardableResult
    public func backupConfig() throws -> URL {
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            throw KarabinerConfigServiceError.configNotFound
        }

        try FileManager.default.createDirectory(at: backupDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        let backupURL = backupDirectoryURL.appendingPathComponent("karabiner-\(backupTimestamp()).json")
        try FileManager.default.copyItem(at: configURL, to: backupURL)
        return backupURL
    }

    public func applyCustomShortcuts(_ definitions: [ShortcutDefinition]) throws -> KarabinerApplyResult {
        let rules = try definitions.map(customRuleDictionary)
        return try applyRules(rules, replacing: .karabinerPlusCustom)
    }

    public func applyRecommendedPacks(_ ids: [String]) throws -> KarabinerApplyResult {
        let rules = recommendedRuleDictionaries(for: ids)
        return try applyRules(rules, replacing: .karabinerPlusRecommended)
    }

    private func applyRules(
        _ newRules: [[String: Any]],
        replacing category: OwnedRuleCategory
    ) throws -> KarabinerApplyResult {
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            throw KarabinerConfigServiceError.configNotFound
        }

        var config = try readConfig()
        ensureProfiles(in: &config)

        guard let selectedIndex = selectedProfileIndex(in: config) else {
            throw KarabinerConfigServiceError.invalidConfig
        }

        var profiles = config["profiles"] as? [[String: Any]] ?? []
        var profile = profiles[selectedIndex]
        ensureComplexModifications(in: &profile)

        let existingRules = currentRules(in: profile)
        let conflictingExistingRules = existingRules.filter { !category.owns(rule: $0) }
        let conflicts = detectConflicts(selectedRules: newRules, existingRules: conflictingExistingRules)
        if !conflicts.isEmpty {
            throw KarabinerConfigServiceError.conflicts(conflicts)
        }

        let mergedRules = existingRules.filter { !category.owns(rule: $0) } + newRules
        var complex = profile["complex_modifications"] as? [String: Any] ?? [:]
        complex["rules"] = mergedRules
        profile["complex_modifications"] = complex
        profiles[selectedIndex] = profile
        config["profiles"] = profiles

        let backupURL = try backupConfig()
        try writeConfig(config)

        return KarabinerApplyResult(
            backupURL: backupURL,
            activeProfileName: profile["name"] as? String
        )
    }

    private func readConfig() throws -> [String: Any] {
        let data = try Data(contentsOf: configURL)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else {
            throw KarabinerConfigServiceError.invalidConfig
        }
        return dictionary
    }

    private func writeConfig(_ config: [String: Any]) throws {
        let jsonData = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
        _ = try JSONSerialization.jsonObject(with: jsonData)

        let output = jsonData + Data([0x0A])
        let directoryURL = configURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)

        let temporaryURL = directoryURL
            .appendingPathComponent(".\(configURL.lastPathComponent).\(ProcessInfo.processInfo.processIdentifier).tmp")

        do {
            try output.write(to: temporaryURL, options: .atomic)
            if FileManager.default.fileExists(atPath: configURL.path) {
                _ = try FileManager.default.replaceItemAt(configURL, withItemAt: temporaryURL)
            } else {
                try FileManager.default.moveItem(at: temporaryURL, to: configURL)
            }
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw error
        }
    }

    private func customRuleDictionary(for definition: ShortcutDefinition) throws -> [String: Any] {
        let rule = ShortcutRuleBuilder.buildCustomRule(definition)
        return try dictionary(for: rule)
    }

    private func recommendedRuleDictionaries(for ids: [String]) -> [[String: Any]] {
        var seen = Set<String>()
        return ids
            .filter { seen.insert($0).inserted }
            .compactMap(recommendedRule(for:))
    }

    private func dictionary<T: Encodable>(for value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else {
            throw KarabinerConfigServiceError.invalidConfig
        }
        return dictionary
    }

    private func detectConflicts(
        selectedRules: [[String: Any]],
        existingRules: [[String: Any]]
    ) -> [KarabinerRuleConflict] {
        var groupedDescriptions: [String: Set<String>] = [:]

        for rule in existingRules + selectedRules {
            let description = String(describing: rule["description"] ?? "Unnamed rule")
            for trigger in triggers(for: rule) {
                groupedDescriptions[trigger, default: []].insert(description)
            }
        }

        return groupedDescriptions
            .filter { $0.value.count > 1 }
            .map { trigger, descriptions in
                KarabinerRuleConflict(
                    trigger: trigger,
                    ruleDescriptions: descriptions.sorted()
                )
            }
            .sorted { $0.trigger < $1.trigger }
    }

    private func triggers(for rule: [String: Any]) -> [String] {
        let manipulators = rule["manipulators"] as? [[String: Any]] ?? []
        return manipulators.compactMap(trigger(for:))
    }

    private func trigger(for manipulator: [String: Any]) -> String? {
        guard
            let from = manipulator["from"] as? [String: Any],
            let source = (from["key_code"] as? String) ??
                (from["consumer_key_code"] as? String) ??
                (from["pointing_button"] as? String)
        else {
            return nil
        }

        let modifiers = (from["modifiers"] as? [String: Any])?["mandatory"] as? [String] ?? []
        return "key:\(source)|mods:\(normalizeModifiers(modifiers).joined(separator: "+"))"
    }

    private func ensureProfiles(in config: inout [String: Any]) {
        if let profiles = config["profiles"] as? [[String: Any]], !profiles.isEmpty {
            return
        }

        config["profiles"] = [defaultProfile()]
    }

    private func ensureComplexModifications(in profile: inout [String: Any]) {
        if profile["simple_modifications"] == nil {
            profile["simple_modifications"] = []
        }

        var complex = profile["complex_modifications"] as? [String: Any] ?? [:]
        if complex["parameters"] == nil {
            complex["parameters"] = defaultComplexParameters()
        }
        if complex["rules"] == nil {
            complex["rules"] = []
        }
        profile["complex_modifications"] = complex
    }

    private func currentRules(in profile: [String: Any]) -> [[String: Any]] {
        let complex = profile["complex_modifications"] as? [String: Any]
        return complex?["rules"] as? [[String: Any]] ?? []
    }

    private func selectedProfile(in config: [String: Any]) -> [String: Any]? {
        guard let profiles = config["profiles"] as? [[String: Any]] else {
            return nil
        }

        return profiles.first(where: { ($0["selected"] as? Bool) == true }) ?? profiles.first
    }

    private func selectedProfileIndex(in config: [String: Any]) -> Int? {
        guard let profiles = config["profiles"] as? [[String: Any]], !profiles.isEmpty else {
            return nil
        }

        return profiles.firstIndex(where: { ($0["selected"] as? Bool) == true }) ?? 0
    }

    private func defaultProfile() -> [String: Any] {
        [
            "name": "Default profile",
            "selected": true,
            "simple_modifications": [],
            "complex_modifications": [
                "parameters": defaultComplexParameters(),
                "rules": [],
            ],
            "devices": [],
            "fn_function_keys": [],
            "virtual_hid_keyboard": [
                "keyboard_type_v2": "ansi",
            ],
        ]
    }

    private func defaultComplexParameters() -> [String: Any] {
        [
            "basic.simultaneous_threshold_milliseconds": 50,
            "basic.to_delayed_action_delay_milliseconds": 500,
            "basic.to_if_alone_timeout_milliseconds": 1000,
            "basic.to_if_held_down_threshold_milliseconds": 500,
            "mouse_motion_to_scroll.speed": 100,
        ]
    }

    private func backupTimestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: now())
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: ".", with: "-")
    }

    private func normalizeModifiers(_ modifiers: [String]) -> [String] {
        Array(Set(modifiers.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })).sorted()
    }
    private func recommendedRule(for id: String) -> [String: Any]? {
        switch id {
        case "slack":
            return makeRecommendedRule(
                title: "Slack",
                bundleIdentifiers: ["com.tinyspeck.slackmacgap"],
                triggerKey: "k"
            )
        case "browser":
            return makeRecommendedRule(
                title: "Browsers",
                bundleIdentifiers: [
                    "com.apple.Safari",
                    "com.google.Chrome",
                    "company.thebrowser.Browser",
                    "org.mozilla.firefox",
                ],
                triggerKey: "l"
            )
        case "media":
            return [
                "description": "[Karabiner+] Recommended: Media",
                "conditions": [
                    [
                        "type": "frontmost_application_if",
                        "bundle_identifiers": [
                            "com.spotify.client",
                            "com.apple.Music",
                        ],
                    ],
                ],
                "manipulators": [
                    [
                        "type": "basic",
                        "from": [
                            "key_code": "spacebar",
                            "modifiers": [
                                "mandatory": ["right_command"],
                                "optional": ["any"],
                            ],
                        ],
                        "to": [
                            [
                                "consumer_key_code": "play_or_pause",
                            ],
                        ],
                    ],
                ],
            ]
        default:
            return nil
        }
    }
}

private enum OwnedRuleCategory {
    case karabinerPlusCustom
    case karabinerPlusRecommended

    func owns(rule: [String: Any]) -> Bool {
        let description = String(describing: rule["description"] ?? "")
        switch self {
        case .karabinerPlusCustom:
            return description.hasPrefix("[Karabiner+] Custom:") ||
                description.hasPrefix("[Karabiner Starter] Custom:")
        case .karabinerPlusRecommended:
            return description.hasPrefix("[Karabiner+] Recommended:") ||
                description.hasPrefix("[Karabiner Starter] Recommended:")
        }
    }
}

private func makeRecommendedRule(
    title: String,
    bundleIdentifiers: [String],
    triggerKey: String
) -> [String: Any] {
    [
        "description": "[Karabiner+] Recommended: \(title)",
        "conditions": [
            [
                "type": "frontmost_application_if",
                "bundle_identifiers": bundleIdentifiers,
            ],
        ],
        "manipulators": [
            [
                "type": "basic",
                "from": [
                    "key_code": triggerKey,
                    "modifiers": [
                        "mandatory": ["right_command"],
                        "optional": ["any"],
                    ],
                ],
                "to": [
                    [
                        "key_code": triggerKey,
                        "modifiers": ["left_command"],
                    ],
                ],
            ],
        ],
    ]
}
