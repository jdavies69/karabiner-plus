import Foundation
import KarabinerPlusCore

@main
struct KarabinerPlusCoreCheck {
    static func main() throws {
        try checkCustomRuleJSON()
        try checkCommandQWarning()
        try checkUsageAccumulator()
        try checkRecommendations()
        try checkMessagesAndPreviewRecommendations()
        try checkConfigServiceCustomMergeAndBackup()
        try checkConfigServiceRecommendedMergeAndConflictDetection()
        print("KarabinerPlusCoreCheck passed")
    }

    private static func checkCustomRuleJSON() throws {
        let definition = ShortcutDefinition(
            name: "Launch Terminal",
            sourceKey: "j",
            sourceModifiers: ["command", "shift"],
            outputKey: "escape",
            outputModifiers: []
        )

        let rule = ShortcutRuleBuilder.buildCustomRule(definition)
        let dictionary = try jsonDictionary(rule)
        try expect(
            dictionary["description"] as? String == "[Karabiner+] Custom: Launch Terminal",
            "custom rule description should use the Karabiner+ prefix"
        )

        let manipulators = try expectValue(
            dictionary["manipulators"] as? [[String: Any]],
            "custom rule should include manipulators"
        )
        try expect(manipulators.count == 1, "custom rule should include one manipulator")
        try expect(manipulators[0]["type"] as? String == "basic", "manipulator should be basic")

        let from = try expectValue(manipulators[0]["from"] as? [String: Any], "from should exist")
        try expect(from["key_code"] as? String == "j", "source key should be encoded")

        let modifiers = try expectValue(from["modifiers"] as? [String: Any], "modifiers should exist")
        try expect(
            modifiers["mandatory"] as? [String] == ["command", "shift"],
            "mandatory source modifiers should be encoded"
        )
        try expect(
            modifiers["optional"] as? [String] == ["any"],
            "optional any modifier should be encoded"
        )

        let to = try expectValue(manipulators[0]["to"] as? [[String: Any]], "to should exist")
        try expect(to.count == 1, "to should include one output")
        try expect(to[0]["key_code"] as? String == "escape", "output key should be encoded")
        try expect(to[0]["modifiers"] == nil, "empty output modifiers should be omitted")
    }

    private static func checkCommandQWarning() throws {
        let definition = ShortcutDefinition(
            name: "Replace Quit",
            sourceKey: "q",
            sourceModifiers: ["command"],
            outputKey: "escape",
            outputModifiers: []
        )

        try expect(
            definition.warnings == [
                ShortcutWarning(
                    message: "Command-Q is a risky macOS shortcut and may override a common system action."
                ),
            ],
            "Command-Q should produce a risky shortcut warning"
        )
    }

    private static func checkUsageAccumulator() throws {
        var accumulator = UsageAccumulator()
        let base = Date(timeIntervalSince1970: 1_719_343_200)

        accumulator.record(
            app: TrackedApp(name: "Slack", bundleIdentifier: "com.tinyspeck.slackmacgap"),
            at: base
        )
        accumulator.record(
            app: TrackedApp(name: "Safari", bundleIdentifier: "com.apple.Safari"),
            at: base.addingTimeInterval(180)
        )
        accumulator.record(
            app: TrackedApp(name: "Safari", bundleIdentifier: "com.apple.Safari"),
            at: base.addingTimeInterval(330)
        )
        accumulator.record(
            app: TrackedApp(name: "Slack", bundleIdentifier: "com.tinyspeck.slackmacgap"),
            at: base.addingTimeInterval(360)
        )

        let totals = Dictionary(uniqueKeysWithValues: accumulator.entries.map { entry in
            (entry.app.bundleIdentifier, entry.seconds)
        })
        try expect(
            totals == [
                "com.tinyspeck.slackmacgap": 180,
                "com.apple.Safari": 180,
            ],
            "usage accumulator should aggregate elapsed time by app"
        )
    }

    private static func checkRecommendations() throws {
        let engine = RecommendationEngine()
        let entries = [
            UsageEntry(app: TrackedApp(name: "Slack", bundleIdentifier: "com.tinyspeck.slackmacgap"), seconds: 240),
            UsageEntry(app: TrackedApp(name: "Safari", bundleIdentifier: "com.apple.Safari"), seconds: 180),
            UsageEntry(app: TrackedApp(name: "Spotify", bundleIdentifier: "com.spotify.client"), seconds: 60),
        ]

        try expect(
            engine.recommendations(for: entries).map(\.id) == ["slack", "browser", "media"],
            "recommendations should rank Slack ahead of browser and media usage"
        )
    }

    private static func checkMessagesAndPreviewRecommendations() throws {
        let engine = RecommendationEngine()
        let entries = [
            UsageEntry(app: TrackedApp(name: "Preview", bundleIdentifier: "com.apple.Preview"), seconds: 120),
            UsageEntry(app: TrackedApp(name: "Messages", bundleIdentifier: "com.apple.MobileSMS"), seconds: 90),
        ]

        try expect(
            engine.recommendations(for: entries).map(\.id) == ["preview", "messages"],
            "recommendations should include Preview and Messages packs"
        )
    }

    private static func checkConfigServiceCustomMergeAndBackup() throws {
        let fixture = try KarabinerFixture()
        defer { try? fixture.remove() }

        try fixture.writeConfig(
            [
                "profiles": [
                    [
                        "name": "Daily",
                        "selected": true,
                        "complex_modifications": [
                            "parameters": defaultComplexParameters(),
                            "rules": [
                                [
                                    "description": "[Karabiner+] Recommended: Slack",
                                    "manipulators": [
                                        basicManipulator(key: "k", mandatory: ["right_command"], toKey: "k", toModifiers: ["left_command"]),
                                    ],
                                ],
                                [
                                    "description": "[Karabiner Starter] Recommended: Browser",
                                    "manipulators": [
                                        basicManipulator(key: "l", mandatory: ["right_command"], toKey: "l", toModifiers: ["left_command"]),
                                    ],
                                ],
                                [
                                    "description": "Imported rule",
                                    "manipulators": [
                                        basicManipulator(key: "u", mandatory: ["control"], toKey: "page_up"),
                                    ],
                                ],
                            ],
                        ],
                        "simple_modifications": [],
                    ],
                ],
            ]
        )

        let service = KarabinerConfigService(
            configURL: fixture.configURL,
            backupDirectoryURL: fixture.backupDirectoryURL
        )
        let status = try service.readStatus()
        try expect(status.configExists, "config status should report an existing config")
        try expect(status.activeProfileName == "Daily", "config status should report the selected profile name")

        let applied = try service.applyCustomShortcuts(
            [
                ShortcutDefinition(
                    name: "Launch Terminal",
                    sourceKey: "j",
                    sourceModifiers: ["command", "shift"],
                    outputKey: "escape",
                    outputModifiers: []
                ),
            ]
        )

        try expect(FileManager.default.fileExists(atPath: applied.backupURL.path), "applying custom shortcuts should create a backup")
        let backupEntries = try FileManager.default.contentsOfDirectory(
            at: fixture.backupDirectoryURL,
            includingPropertiesForKeys: nil
        )
        try expect(backupEntries.count == 1, "custom apply should create one backup in the backup directory")

        let config = try fixture.readConfig()
        let profile = try selectedProfile(from: config)
        let complex = try expectDictionary(
            profile["complex_modifications"] as? [String: Any],
            "selected profile should have complex modifications"
        )
        let rules = try expectArray(complex["rules"] as? [[String: Any]], "selected profile should have complex rules")
        let descriptions = rules.compactMap { $0["description"] as? String }

        try expect(
            descriptions.contains("[Karabiner+] Custom: Launch Terminal"),
            "custom apply should write the Karabiner+ custom rule"
        )
        try expect(
            descriptions.contains("[Karabiner+] Recommended: Slack"),
            "custom apply should preserve Karabiner+ recommended rules"
        )
        try expect(
            descriptions.contains("[Karabiner Starter] Recommended: Browser"),
            "custom apply should preserve legacy recommended rules"
        )
        try expect(
            descriptions.contains("Imported rule"),
            "custom apply should preserve unrelated user rules"
        )
        try expect(
            descriptions.filter { $0 == "[Karabiner+] Custom: Launch Terminal" }.count == 1,
            "custom apply should replace owned custom rules without duplicating them"
        )
    }

    private static func checkConfigServiceRecommendedMergeAndConflictDetection() throws {
        let fixture = try KarabinerFixture()
        defer { try? fixture.remove() }

        try fixture.writeConfig(
            [
                "profiles": [
                    [
                        "name": "Work",
                        "selected": true,
                        "complex_modifications": [
                            "parameters": defaultComplexParameters(),
                            "rules": [
                                [
                                    "description": "[Karabiner Starter] Custom: Existing legacy custom",
                                    "manipulators": [
                                        basicManipulator(key: "semicolon", mandatory: ["command"], toKey: "tab"),
                                    ],
                                ],
                                [
                                    "description": "Imported browser rule",
                                    "manipulators": [
                                        basicManipulator(key: "l", mandatory: ["right_command"], toKey: "tab"),
                                    ],
                                ],
                            ],
                        ],
                        "simple_modifications": [],
                    ],
                ],
            ]
        )

        let service = KarabinerConfigService(
            configURL: fixture.configURL,
            backupDirectoryURL: fixture.backupDirectoryURL
        )

        do {
            _ = try service.applyRecommendedPacks(["browser"])
            throw CheckFailure("recommended apply should reject conflicts against non-owned rules")
        } catch let error as KarabinerConfigServiceError {
            guard case .conflicts(let conflicts) = error else {
                throw error
            }

            try expect(
                conflicts.contains { $0.trigger == "key:l|mods:right_command" && $0.ruleDescriptions.contains("Imported browser rule") },
                "conflict should report the colliding trigger and existing rule"
            )
        }

        try fixture.writeConfig(
            [
                "profiles": [
                    [
                        "name": "Work",
                        "selected": true,
                        "complex_modifications": [
                            "parameters": defaultComplexParameters(),
                            "rules": [
                                [
                                    "description": "[Karabiner Starter] Custom: Existing legacy custom",
                                    "manipulators": [
                                        basicManipulator(key: "semicolon", mandatory: ["command"], toKey: "tab"),
                                    ],
                                ],
                                [
                                    "description": "[Karabiner+] Custom: Existing native custom",
                                    "manipulators": [
                                        basicManipulator(key: "j", mandatory: ["command"], toKey: "escape"),
                                    ],
                                ],
                            ],
                        ],
                        "simple_modifications": [],
                    ],
                ],
            ]
        )

        let applied = try service.applyRecommendedPacks(["slack"])
        try expect(FileManager.default.fileExists(atPath: applied.backupURL.path), "recommended apply should create a backup")

        let config = try fixture.readConfig()
        let profile = try selectedProfile(from: config)
        let complex = try expectDictionary(
            profile["complex_modifications"] as? [String: Any],
            "selected profile should have complex modifications"
        )
        let rules = try expectArray(complex["rules"] as? [[String: Any]], "selected profile should have complex rules")
        let descriptions = rules.compactMap { $0["description"] as? String }

        try expect(
            descriptions.contains("[Karabiner+] Recommended: Slack"),
            "recommended apply should write the Karabiner+ recommended rule"
        )
        try expect(
            descriptions.contains("[Karabiner Starter] Custom: Existing legacy custom"),
            "recommended apply should preserve legacy custom rules"
        )
        try expect(
            descriptions.contains("[Karabiner+] Custom: Existing native custom"),
            "recommended apply should preserve Karabiner+ custom rules"
        )
    }

    private static func jsonDictionary<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try expectValue(
            JSONSerialization.jsonObject(with: data) as? [String: Any],
            "encoded value should be a dictionary"
        )
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        if !condition {
            throw CheckFailure(message)
        }
    }

    private static func expectValue<T>(_ value: T?, _ message: String) throws -> T {
        guard let value else {
            throw CheckFailure(message)
        }
        return value
    }
}

private struct KarabinerFixture {
    let rootURL: URL
    let configURL: URL
    let backupDirectoryURL: URL

    init() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("karabiner-plus-core-check-\(UUID().uuidString)", isDirectory: true)
        self.rootURL = rootURL
        configURL = rootURL.appendingPathComponent("karabiner.json")
        backupDirectoryURL = rootURL.appendingPathComponent("backups", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true, attributes: nil)
    }

    func writeConfig(_ object: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: configURL)
    }

    func readConfig() throws -> [String: Any] {
        let data = try Data(contentsOf: configURL)
        return try expectDictionary(
            JSONSerialization.jsonObject(with: data) as? [String: Any],
            "fixture config should decode to a dictionary"
        )
    }

    func remove() throws {
        try FileManager.default.removeItem(at: rootURL)
    }
}

private func selectedProfile(from config: [String: Any]) throws -> [String: Any] {
    let profiles = try expectArray(config["profiles"] as? [[String: Any]], "config should contain profiles")

    if let selected = profiles.first(where: { ($0["selected"] as? Bool) == true }) {
        return selected
    }

    return try expectDictionary(profiles.first, "config should contain a profile")
}

private func basicManipulator(
    key: String,
    mandatory: [String],
    toKey: String,
    toModifiers: [String] = []
) -> [String: Any] {
    var to: [String: Any] = ["key_code": toKey]
    if !toModifiers.isEmpty {
        to["modifiers"] = toModifiers
    }

    return [
        "type": "basic",
        "from": [
            "key_code": key,
            "modifiers": [
                "mandatory": mandatory,
                "optional": ["any"],
            ],
        ],
        "to": [to],
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

private func expectDictionary(_ value: [String: Any]?, _ message: String) throws -> [String: Any] {
    guard let value else {
        throw CheckFailure(message)
    }
    return value
}

private func expectArray<T>(_ value: [T]?, _ message: String) throws -> [T] {
    guard let value else {
        throw CheckFailure(message)
    }
    return value
}

struct CheckFailure: Error, CustomStringConvertible {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var description: String {
        message
    }
}
