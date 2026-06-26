import Foundation
import KarabinerPlusCore

@main
struct KarabinerPlusCoreCheck {
    static func main() throws {
        try checkCustomRuleJSON()
        try checkAppSpecificCustomRuleJSON()
        try checkLauncherSequenceRuleJSON()
        try checkCommandQWarning()
        try checkOutputCommandWarning()
        try checkPlainLetterWarning()
        try checkUsageAccumulator()
        try checkRecommendations()
        try checkMessagesAndPreviewRecommendations()
        try checkLauncherSequenceSuggestions()
        try checkLauncherSequenceValidation()
        try checkConfigServiceReadsCustomShortcuts()
        try checkConfigServiceReadsAppSpecificCustomShortcuts()
        try checkConfigServiceCustomMergeAndBackup()
        try checkConfigServicePreviewsCustomApplySummary()
        try checkConfigServiceListsAndRestoresBackups()
        try checkConfigServiceModifierOverlapConflicts()
        try checkConfigServiceRecommendedMergeAndConflictDetection()
        try checkConfigServiceLauncherSequenceSummary()
        try checkConfigServiceRejectsAmbiguousLauncherSequences()
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

    private static func checkAppSpecificCustomRuleJSON() throws {
        let definition = ShortcutDefinition(
            name: "Slack Escape",
            sourceKey: "j",
            sourceModifiers: ["right_command"],
            outputKey: "escape",
            outputModifiers: [],
            appBundleIdentifier: "com.tinyspeck.slackmacgap",
            appName: "Slack"
        )

        let rule = ShortcutRuleBuilder.buildCustomRule(definition)
        let dictionary = try jsonDictionary(rule)
        let manipulators = try expectValue(
            dictionary["manipulators"] as? [[String: Any]],
            "custom rule should include manipulators"
        )
        let conditions = try expectValue(
            manipulators[0]["conditions"] as? [[String: Any]],
            "app-specific custom rule should include manipulator conditions"
        )

        try expect(conditions.count == 1, "app-specific custom rule should include one condition")
        try expect(
            conditions[0]["type"] as? String == "frontmost_application_if",
            "app-specific custom rule should use a frontmost application condition"
        )
        try expect(
            conditions[0]["bundle_identifiers"] as? [String] == ["^com\\.tinyspeck\\.slackmacgap$"],
            "app-specific custom rule should use an exact bundle identifier condition"
        )
    }

    private static func checkLauncherSequenceRuleJSON() throws {
        let rules = LauncherSequenceRuleBuilder.buildRules(
            [
                LauncherSequenceDefinition(
                    appName: "Codex",
                    bundleIdentifier: "com.openai.codex",
                    sequence: ["c", "o"]
                ),
                LauncherSequenceDefinition(
                    appName: "ChatGPT",
                    bundleIdentifier: "com.openai.chat",
                    sequence: ["c", "h"]
                ),
                LauncherSequenceDefinition(
                    appName: "Superhuman",
                    bundleIdentifier: "com.superhuman.Superhuman",
                    sequence: ["s", "u"]
                ),
            ]
        )

        try expect(rules.count == 1, "launcher sequences should build one owned rule")
        let rule = rules[0]
        try expect(
            rule["description"] as? String == "[Karabiner+] Launcher Sequences",
            "launcher rule should use the Karabiner+ launcher description"
        )

        let manipulators = try expectValue(
            rule["manipulators"] as? [[String: Any]],
            "launcher rule should include manipulators"
        )
        try expect(
            manipulators.count == 6,
            "three launcher definitions with two shared prefixes should produce leader, two prefix, and three launch manipulators"
        )

        let leaderFrom = try expectDictionary(
            manipulators[0]["from"] as? [String: Any],
            "leader manipulator should include a from object"
        )
        try expect(leaderFrom["key_code"] as? String == "right_command", "launcher leader should use right_command")

        let codexLaunch = try expectValue(
            manipulators.first { manipulator in
                guard let to = manipulator["to"] as? [[String: Any]] else { return false }
                return to.contains { ($0["shell_command"] as? String)?.contains("com.openai.codex") == true }
            },
            "launcher rule should include a Codex shell command"
        )
        let conditions = try expectValue(
            codexLaunch["conditions"] as? [[String: Any]],
            "Codex launcher should include sequence conditions"
        )
        try expect(
            conditions.contains { $0["name"] as? String == "karabiner_plus_launcher_active" && $0["value"] as? Int == 1 },
            "Codex launcher should require the right-command launcher to be active"
        )
        try expect(
            conditions.contains { $0["name"] as? String == "karabiner_plus_launcher_prefix" && $0["value"] as? String == "c" },
            "Codex launcher should require the C prefix before O"
        )
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

    private static func checkPlainLetterWarning() throws {
        let definition = ShortcutDefinition(
            name: "Replace A",
            sourceKey: "a",
            sourceModifiers: [],
            outputKey: "escape",
            outputModifiers: []
        )

        try expect(
            definition.warnings == [
                ShortcutWarning(
                    message: "A will stop typing normally everywhere. Add a modifier unless you really mean to replace that key."
                ),
            ],
            "plain key remaps should warn because they affect normal typing"
        )

        try expect(
            ShortcutDefinition(
                name: "Space to Escape",
                sourceKey: "spacebar",
                sourceModifiers: [],
                outputKey: "escape",
                outputModifiers: []
            ).warnings == [
                ShortcutWarning(
                    message: "Spacebar will stop typing normally everywhere. Add a modifier unless you really mean to replace that key."
                ),
            ],
            "plain spacebar remaps should warn because they affect normal typing"
        )

        try expect(
            ShortcutDefinition(
                name: "No Change",
                sourceKey: "escape",
                sourceModifiers: [],
                outputKey: "escape",
                outputModifiers: []
            ).isNoOp,
            "identical source and output should be detected as a no-op"
        )
    }

    private static func checkConfigServiceModifierOverlapConflicts() throws {
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
                                    "description": "Imported generic Command H",
                                    "manipulators": [
                                        basicManipulator(key: "h", mandatory: ["command"], toKey: "left_arrow"),
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
            _ = try service.applyCustomShortcuts(
                [
                    ShortcutDefinition(
                        name: "Right Command H",
                        sourceKey: "h",
                        sourceModifiers: ["right_command"],
                        outputKey: "left_arrow",
                        outputModifiers: []
                    ),
                ]
            )
            throw CheckFailure("custom apply should reject generic Command overlap with Right Command")
        } catch let error as KarabinerConfigServiceError {
            guard case .conflicts(let conflicts) = error else {
                throw error
            }

            try expect(
                conflicts.contains {
                    $0.trigger.contains("key:h|mods:command") &&
                        $0.trigger.contains("key:h|mods:right_command") &&
                        $0.ruleDescriptions.contains("Imported generic Command H") &&
                        $0.ruleDescriptions.contains("[Karabiner+] Custom: Right Command H")
                },
                "Swift conflict detection should catch generic Command overlap with Right Command"
            )
        }
    }

    private static func checkOutputCommandWarning() throws {
        let definition = ShortcutDefinition(
            name: "Dangerous Output",
            sourceKey: "j",
            sourceModifiers: ["right_command"],
            outputKey: "q",
            outputModifiers: ["command"]
        )

        try expect(
            definition.warnings == [
                ShortcutWarning(
                    message: "This sends Command-Q, which may trigger a common macOS action."
                ),
            ],
            "shortcuts that send risky Command actions should warn"
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

    private static func checkLauncherSequenceSuggestions() throws {
        let engine = LauncherSequenceEngine()
        let suggestions = engine.suggestions(
            for: [
                UsageEntry(app: TrackedApp(name: "Codex", bundleIdentifier: "com.openai.codex"), seconds: 240),
                UsageEntry(app: TrackedApp(name: "ChatGPT", bundleIdentifier: "com.openai.chat"), seconds: 220),
                UsageEntry(app: TrackedApp(name: "Superhuman", bundleIdentifier: "com.superhuman.Superhuman"), seconds: 200),
                UsageEntry(app: TrackedApp(name: "loginwindow", bundleIdentifier: ""), seconds: 180),
            ]
        )

        try expect(
            suggestions.map { $0.definition.appName } == ["Codex", "ChatGPT", "Superhuman"],
            "launcher suggestions should skip apps without bundle identifiers"
        )
        try expect(
            suggestions.map { $0.definition.sequenceLabel } == ["C O", "C H", "S U"],
            "launcher suggestions should choose distinct mnemonic sequences from app names"
        )

        let prefixSensitiveSuggestions = engine.suggestions(
            for: [
                UsageEntry(app: TrackedApp(name: "A", bundleIdentifier: "com.example.a"), seconds: 300),
                UsageEntry(app: TrackedApp(name: "Arc", bundleIdentifier: "company.thebrowser.Browser"), seconds: 200),
            ]
        )
        try expect(
            LauncherSequenceRuleBuilder.validationIssues(for: prefixSensitiveSuggestions.map(\.definition)).isEmpty,
            "launcher suggestions should avoid prefix-overlapping defaults"
        )
    }

    private static func checkLauncherSequenceValidation() throws {
        let issues = LauncherSequenceRuleBuilder.validationIssues(
            for: [
                LauncherSequenceDefinition(
                    appName: "Codex",
                    bundleIdentifier: "com.openai.codex",
                    sequence: ["c"]
                ),
                LauncherSequenceDefinition(
                    appName: "ChatGPT",
                    bundleIdentifier: "com.openai.chat",
                    sequence: ["c", "h"]
                ),
                LauncherSequenceDefinition(
                    appName: "Superhuman",
                    bundleIdentifier: "com.superhuman.Superhuman",
                    sequence: ["s", "u"]
                ),
                LauncherSequenceDefinition(
                    appName: "Slack",
                    bundleIdentifier: "com.tinyspeck.slackmacgap",
                    sequence: ["s", "u"]
                ),
            ]
        )

        try expect(issues.count == 2, "launcher validation should find duplicate and prefix conflicts")
        try expect(
            issues.contains {
                $0.kind == .prefixOverlap &&
                    $0.sequenceLabel == "C" &&
                    $0.appNames == ["ChatGPT", "Codex"]
            },
            "launcher validation should flag one-key launchers that shadow two-key launchers"
        )
        try expect(
            issues.contains {
                $0.kind == .duplicate &&
                    $0.sequenceLabel == "S U" &&
                    $0.appNames == ["Slack", "Superhuman"]
            },
            "launcher validation should flag duplicate edited sequences"
        )
    }

    private static func checkConfigServiceReadsCustomShortcuts() throws {
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
                                    "description": "[Karabiner+] Custom: Caps Lock to Escape",
                                    "manipulators": [
                                        basicManipulator(key: "caps_lock", mandatory: [], toKey: "escape"),
                                    ],
                                ],
                                [
                                    "description": "[Karabiner Starter] Custom: Right Command H",
                                    "manipulators": [
                                        basicManipulator(key: "h", mandatory: ["right_command"], toKey: "left_arrow"),
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
        let shortcuts = try service.readCustomShortcuts()

        try expect(
            shortcuts.map(\.name) == ["Caps Lock to Escape", "Right Command H"],
            "service should read native and legacy custom Studio shortcuts"
        )
        try expect(
            shortcuts[0] == ShortcutDefinition(
                name: "Caps Lock to Escape",
                sourceKey: "caps_lock",
                sourceModifiers: [],
                outputKey: "escape",
                outputModifiers: []
            ),
            "service should parse the custom shortcut shape back into a definition"
        )
    }

    private static func checkConfigServiceReadsAppSpecificCustomShortcuts() throws {
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
                                    "description": "[Karabiner+] Custom: Slack Escape",
                                    "manipulators": [
                                        basicManipulator(
                                            key: "j",
                                            mandatory: ["right_command"],
                                            toKey: "escape",
                                            conditions: [
                                                [
                                                    "type": "frontmost_application_if",
                                                    "bundle_identifiers": ["^com\\.tinyspeck\\.slackmacgap$"],
                                                ],
                                            ]
                                        ),
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
        let shortcuts = try service.readCustomShortcuts()

        try expect(
            shortcuts == [
                ShortcutDefinition(
                    name: "Slack Escape",
                    sourceKey: "j",
                    sourceModifiers: ["right_command"],
                    outputKey: "escape",
                    outputModifiers: [],
                    appBundleIdentifier: "com.tinyspeck.slackmacgap"
                ),
            ],
            "service should read app-specific custom shortcut conditions"
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

    private static func checkConfigServicePreviewsCustomApplySummary() throws {
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
                                    "description": "[Karabiner+] Custom: Old Studio Rule",
                                    "manipulators": [
                                        basicManipulator(key: "j", mandatory: ["right_command"], toKey: "escape"),
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

        let summary = try service.previewCustomShortcutApply(
            [
                ShortcutDefinition(
                    name: "New Studio Rule",
                    sourceKey: "k",
                    sourceModifiers: ["right_command"],
                    outputKey: "escape",
                    outputModifiers: []
                ),
            ]
        )

        try expect(
            summary == KarabinerApplySummary(
                activeProfileName: "Daily",
                addedRuleCount: 1,
                replacedOwnedRuleCount: 1,
                preservedRuleCount: 1,
                conflictCount: 0
            ),
            "custom preview summary should count added, replaced, preserved, and conflicts without writing"
        )
    }

    private static func checkConfigServiceListsAndRestoresBackups() throws {
        let fixture = try KarabinerFixture()
        defer { try? fixture.remove() }

        try fixture.writeConfig(named: "Before Restore")

        let clock = SequenceClock(start: Date(timeIntervalSince1970: 1_719_343_200))
        let service = KarabinerConfigService(
            configURL: fixture.configURL,
            backupDirectoryURL: fixture.backupDirectoryURL,
            now: clock.now
        )

        let olderBackupURL = try service.backupConfig()
        try fixture.writeConfig(named: "After Restore")
        let newerBackupURL = try service.backupConfig()

        let backups = try service.listBackups()
        try expect(
            backups.map(\.name) == [newerBackupURL.lastPathComponent, olderBackupURL.lastPathComponent],
            "backups should list newest first"
        )

        let result = try service.restoreBackup(backups[1])
        try expect(
            FileManager.default.fileExists(atPath: result.preRestoreBackupURL.path),
            "restore should create a pre-restore backup"
        )

        let restoredConfig = try fixture.readConfig()
        let restoredProfile = try selectedProfile(from: restoredConfig)
        try expect(
            restoredProfile["name"] as? String == "Before Restore",
            "restore should replace the active config with the selected backup"
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

    private static func checkConfigServiceLauncherSequenceSummary() throws {
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
                                    "description": "[Karabiner+] Launcher Sequences",
                                    "manipulators": [
                                        basicManipulator(key: "m", mandatory: ["right_command"], toKey: "m"),
                                    ],
                                ],
                                [
                                    "description": "Imported rule",
                                    "manipulators": [
                                        basicManipulator(key: "u", mandatory: ["control"], toKey: "page_up"),
                                    ],
                                ],
                                [
                                    "description": "[Karabiner+] Launcher Manual Rule",
                                    "manipulators": [
                                        basicManipulator(key: "i", mandatory: ["control"], toKey: "page_down"),
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
        let definitions = [
            LauncherSequenceDefinition(
                appName: "Superhuman",
                bundleIdentifier: "com.superhuman.Superhuman",
                sequence: ["m"]
            ),
        ]

        let summary = try service.previewLauncherSequenceApply(definitions)
        try expect(summary.activeProfileName == "Daily", "launcher preview active profile should be Daily")
        try expect(summary.addedRuleCount == 1, "launcher preview should write one rule")
        try expect(
            summary.replacedOwnedRuleCount == 1,
            "launcher preview should replace one generated launcher rule, got \(summary.replacedOwnedRuleCount)"
        )
        try expect(
            summary.preservedRuleCount == 2,
            "launcher preview should preserve two unrelated rules, got \(summary.preservedRuleCount)"
        )
        try expect(summary.conflictCount == 0, "launcher preview should not report conflicts")

        let result = try service.applyLauncherSequences(definitions)
        try expect(FileManager.default.fileExists(atPath: result.backupURL.path), "launcher apply should create a backup")

        let config = try fixture.readConfig()
        let profile = try selectedProfile(from: config)
        let complex = try expectDictionary(
            profile["complex_modifications"] as? [String: Any],
            "selected profile should have complex modifications"
        )
        let rules = try expectArray(complex["rules"] as? [[String: Any]], "selected profile should have complex rules")
        let descriptions = rules.compactMap { $0["description"] as? String }
        try expect(
            descriptions.contains("[Karabiner+] Launcher Manual Rule"),
            "launcher apply should preserve launcher-like rules that Karabiner+ did not generate"
        )
    }

    private static func checkConfigServiceRejectsAmbiguousLauncherSequences() throws {
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
                            "rules": [],
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
            _ = try service.previewLauncherSequenceApply(
                [
                    LauncherSequenceDefinition(
                        appName: "Codex",
                        bundleIdentifier: "com.openai.codex",
                        sequence: ["c"]
                    ),
                    LauncherSequenceDefinition(
                        appName: "ChatGPT",
                        bundleIdentifier: "com.openai.chat",
                        sequence: ["c", "h"]
                    ),
                ]
            )
            throw CheckFailure("launcher preview should reject prefix-overlapping sequences")
        } catch let KarabinerConfigServiceError.invalidLauncherSequences(issues) {
            try expect(
                issues.map(\.kind) == [.prefixOverlap],
                "launcher preview should report the sequence conflict"
            )
        }
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

    func writeConfig(named profileName: String) throws {
        try writeConfig(
            [
                "profiles": [
                    [
                        "name": profileName,
                        "selected": true,
                        "complex_modifications": [
                            "parameters": defaultComplexParameters(),
                            "rules": [],
                        ],
                        "simple_modifications": [],
                    ],
                ],
            ]
        )
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
    toModifiers: [String] = [],
    conditions: [[String: Any]] = []
) -> [String: Any] {
    var to: [String: Any] = ["key_code": toKey]
    if !toModifiers.isEmpty {
        to["modifiers"] = toModifiers
    }

    var manipulator: [String: Any] = [
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
    if !conditions.isEmpty {
        manipulator["conditions"] = conditions
    }

    return manipulator
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

private final class SequenceClock: @unchecked Sendable {
    private var nextDate: Date

    init(start: Date) {
        nextDate = start
    }

    func now() -> Date {
        defer { nextDate = nextDate.addingTimeInterval(1) }
        return nextDate
    }
}
