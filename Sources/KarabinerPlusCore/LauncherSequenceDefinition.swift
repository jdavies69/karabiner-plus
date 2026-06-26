import Foundation

private let launcherRuleDescription = "[Karabiner+] Launcher Sequences"
private let launcherActiveVariable = "karabiner_plus_launcher_active"
private let launcherPrefixVariable = "karabiner_plus_launcher_prefix"

public struct LauncherSequenceDefinition: Codable, Equatable, Identifiable, Sendable {
    public let appName: String
    public let bundleIdentifier: String
    public let sequence: [String]

    public var id: String {
        bundleIdentifier.isEmpty ? appName.lowercased() : bundleIdentifier.lowercased()
    }

    public init(appName: String, bundleIdentifier: String, sequence: [String]) {
        self.appName = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.bundleIdentifier = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sequence = Array(sequence
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            .prefix(2))
    }

    public var isValid: Bool {
        !appName.isEmpty &&
            !bundleIdentifier.isEmpty &&
            bundleIdentifier.range(of: #"^[A-Za-z0-9.-]+$"#, options: .regularExpression) != nil &&
            !sequence.isEmpty &&
            sequence.count <= 2 &&
            sequence.allSatisfy { $0.range(of: #"^[a-z0-9]$"#, options: .regularExpression) != nil }
    }

    public var sequenceLabel: String {
        sequence.map { $0.uppercased() }.joined(separator: " ")
    }
}

public struct LauncherSequenceValidationIssue: Equatable, Identifiable, Sendable {
    public enum Kind: Equatable, Sendable {
        case duplicate
        case prefixOverlap
    }

    public let kind: Kind
    public let sequence: [String]
    public let appNames: [String]

    public var id: String {
        "\(kind)-\(sequence.joined())-\(appNames.joined(separator: ","))"
    }

    public var sequenceLabel: String {
        sequence.map { $0.uppercased() }.joined(separator: " ")
    }

    public var message: String {
        let names = appNames.joined(separator: ", ")
        switch kind {
        case .duplicate:
            return "\(sequenceLabel) is assigned to more than one app: \(names). Pick a unique sequence."
        case .prefixOverlap:
            return "\(sequenceLabel) conflicts with a longer sequence for \(names). Use a different one-letter shortcut."
        }
    }

    public init(kind: Kind, sequence: [String], appNames: [String]) {
        self.kind = kind
        self.sequence = sequence
        self.appNames = appNames.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}

public enum LauncherSequenceRuleBuilder {
    public static let ruleDescription = launcherRuleDescription

    public static func validationIssues(for definitions: [LauncherSequenceDefinition]) -> [LauncherSequenceValidationIssue] {
        let validDefinitions = definitions.filter(\.isValid)
        var issues: [LauncherSequenceValidationIssue] = []

        let groupedBySequence = Dictionary(grouping: validDefinitions, by: sequenceKey)
        for (key, definitions) in groupedBySequence where definitions.count > 1 {
            issues.append(
                LauncherSequenceValidationIssue(
                    kind: .duplicate,
                    sequence: sequence(from: key),
                    appNames: definitions.map(\.appName)
                )
            )
        }

        let oneKeyDefinitions = validDefinitions.filter { $0.sequence.count == 1 }
        let twoKeyDefinitions = validDefinitions.filter { $0.sequence.count == 2 }

        for oneKeyDefinition in oneKeyDefinitions {
            let overlapping = twoKeyDefinitions.filter {
                $0.sequence.first == oneKeyDefinition.sequence.first
            }

            guard !overlapping.isEmpty else {
                continue
            }

            issues.append(
                LauncherSequenceValidationIssue(
                    kind: .prefixOverlap,
                    sequence: oneKeyDefinition.sequence,
                    appNames: ([oneKeyDefinition] + overlapping).map(\.appName)
                )
            )
        }

        return issues.sorted {
            if $0.sequenceLabel != $1.sequenceLabel {
                return $0.sequenceLabel < $1.sequenceLabel
            }

            return $0.id < $1.id
        }
    }

    public static func buildRules(_ definitions: [LauncherSequenceDefinition]) -> [[String: Any]] {
        let validDefinitions = definitions.filter(\.isValid)
        guard !validDefinitions.isEmpty,
              validationIssues(for: validDefinitions).isEmpty
        else {
            return []
        }

        var manipulators: [[String: Any]] = [leaderManipulator()]

        let prefixes = Set(validDefinitions.compactMap { definition in
            definition.sequence.count == 2 ? definition.sequence[0] : nil
        }).sorted()

        for prefix in prefixes {
            manipulators.append(prefixManipulator(prefix))
        }

        for definition in validDefinitions {
            manipulators.append(launchManipulator(definition))
        }

        return [
            [
                "description": launcherRuleDescription,
                "manipulators": manipulators,
            ],
        ]
    }

    private static func leaderManipulator() -> [String: Any] {
        [
            "type": "basic",
            "from": [
                "key_code": "right_command",
                "modifiers": [
                    "optional": ["any"],
                ],
            ],
            "to": [
                setVariable(name: launcherActiveVariable, value: 1),
                setVariable(name: launcherPrefixVariable, value: ""),
            ],
            "to_after_key_up": [
                setVariable(name: launcherActiveVariable, value: 0),
                setVariable(name: launcherPrefixVariable, value: ""),
            ],
        ]
    }

    private static func prefixManipulator(_ prefix: String) -> [String: Any] {
        [
            "type": "basic",
            "from": [
                "key_code": prefix,
                "modifiers": [
                    "optional": ["any"],
                ],
            ],
            "conditions": [
                variableCondition(name: launcherActiveVariable, value: 1),
            ],
            "to": [
                setVariable(name: launcherPrefixVariable, value: prefix),
            ],
        ]
    }

    private static func launchManipulator(_ definition: LauncherSequenceDefinition) -> [String: Any] {
        let triggerKey = definition.sequence.last ?? ""
        var conditions = [
            variableCondition(name: launcherActiveVariable, value: 1),
        ]

        if definition.sequence.count == 2 {
            conditions.append(variableCondition(name: launcherPrefixVariable, value: definition.sequence[0]))
        }

        return [
            "type": "basic",
            "from": [
                "key_code": triggerKey,
                "modifiers": [
                    "optional": ["any"],
                ],
            ],
            "conditions": conditions,
            "to": [
                [
                    "shell_command": "/usr/bin/open -b \(shellQuoted(definition.bundleIdentifier))",
                ],
                setVariable(name: launcherPrefixVariable, value: ""),
            ],
        ]
    }

    private static func variableCondition(name: String, value: Any) -> [String: Any] {
        [
            "type": "variable_if",
            "name": name,
            "value": value,
        ]
    }

    private static func setVariable(name: String, value: Any) -> [String: Any] {
        [
            "set_variable": [
                "name": name,
                "value": value,
            ],
        ]
    }

    private static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private static func sequenceKey(for definition: LauncherSequenceDefinition) -> String {
        definition.sequence.joined()
    }

    private static func sequence(from key: String) -> [String] {
        key.map(String.init)
    }
}
