import Foundation

private let karabinerPlusCustomPrefix = "[Karabiner+] Custom:"
private let riskyShortcutKeys: Set<String> = ["q", "w", "tab", "spacebar", "c", "v", "x", "z", "s"]
private let commandModifiers: Set<String> = ["command", "left_command", "right_command"]

public struct ShortcutDefinition: Equatable, Sendable {
    public let name: String
    public let sourceKey: String
    public let sourceModifiers: [String]
    public let outputKey: String
    public let outputModifiers: [String]

    public init(
        name: String,
        sourceKey: String,
        sourceModifiers: [String],
        outputKey: String,
        outputModifiers: [String]
    ) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceKey = sourceKey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.sourceModifiers = ShortcutDefinition.normalizeModifiers(sourceModifiers)
        self.outputKey = outputKey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.outputModifiers = ShortcutDefinition.normalizeModifiers(outputModifiers)
    }

    public var warnings: [ShortcutWarning] {
        guard riskyShortcutKeys.contains(sourceKey) else {
            return []
        }

        guard sourceModifiers.contains(where: { commandModifiers.contains($0) }) else {
            return []
        }

        return [
            ShortcutWarning(
                message: "\(formatWarningShortcut(modifiers: sourceModifiers, key: sourceKey)) is a risky macOS shortcut and may override a common system action."
            ),
        ]
    }

    private static func normalizeModifiers(_ modifiers: [String]) -> [String] {
        var seen = Set<String>()

        return modifiers
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
    }
}

public struct ShortcutWarning: Equatable, Sendable {
    public let message: String

    public init(message: String) {
        self.message = message
    }
}

public enum ShortcutRuleBuilder {
    public static func buildCustomRule(_ definition: ShortcutDefinition) -> KarabinerRule {
        KarabinerRule(
            description: "\(karabinerPlusCustomPrefix) \(definition.name)",
            manipulators: [
                KarabinerManipulator(
                    from: KarabinerFrom(
                        keyCode: definition.sourceKey,
                        modifiers: KarabinerModifiers(
                            mandatory: definition.sourceModifiers.isEmpty ? nil : definition.sourceModifiers,
                            optional: ["any"]
                        )
                    ),
                    to: [
                        KarabinerTo(
                            keyCode: definition.outputKey,
                            modifiers: definition.outputModifiers.isEmpty ? nil : definition.outputModifiers
                        ),
                    ]
                ),
            ]
        )
    }
}

public struct KarabinerRule: Encodable, Equatable, Sendable {
    public let description: String
    public let manipulators: [KarabinerManipulator]

    public init(description: String, manipulators: [KarabinerManipulator]) {
        self.description = description
        self.manipulators = manipulators
    }
}

public struct KarabinerManipulator: Encodable, Equatable, Sendable {
    public let type = "basic"
    public let from: KarabinerFrom
    public let to: [KarabinerTo]

    public init(from: KarabinerFrom, to: [KarabinerTo]) {
        self.from = from
        self.to = to
    }
}

public struct KarabinerFrom: Encodable, Equatable, Sendable {
    public let keyCode: String
    public let modifiers: KarabinerModifiers

    public init(keyCode: String, modifiers: KarabinerModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    enum CodingKeys: String, CodingKey {
        case keyCode = "key_code"
        case modifiers
    }
}

public struct KarabinerModifiers: Encodable, Equatable, Sendable {
    public let mandatory: [String]?
    public let optional: [String]

    public init(mandatory: [String]?, optional: [String]) {
        self.mandatory = mandatory
        self.optional = optional
    }
}

public struct KarabinerTo: Encodable, Equatable, Sendable {
    public let keyCode: String
    public let modifiers: [String]?

    public init(keyCode: String, modifiers: [String]?) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    enum CodingKeys: String, CodingKey {
        case keyCode = "key_code"
        case modifiers
    }
}

private func formatWarningShortcut(modifiers: [String], key: String) -> String {
    ([modifiers.map(formatModifier), formatKey(key)] as [Any])
        .flatMap { element -> [String] in
            if let values = element as? [String] {
                return values
            }

            if let value = element as? String {
                return [value]
            }

            return []
        }
        .joined(separator: "-")
}

private func formatModifier(_ modifier: String) -> String {
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
        return modifier
    }
}

private func formatKey(_ key: String) -> String {
    switch key {
    case "escape":
        return "Escape"
    case "tab":
        return "Tab"
    case "spacebar":
        return "Spacebar"
    case "return_or_enter":
        return "Return/Enter"
    default:
        return key.uppercased()
    }
}
