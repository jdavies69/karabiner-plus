import Foundation
import KeyTailorCore

@main
struct KeyTailorCoreCheck {
    static func main() throws {
        try checkCustomRuleJSON()
        try checkCommandQWarning()
        try checkUsageAccumulator()
        try checkRecommendations()
        print("KeyTailorCoreCheck passed")
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
            dictionary["description"] as? String == "[KeyTailor] Custom: Launch Terminal",
            "custom rule description should use the KeyTailor prefix"
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

struct CheckFailure: Error, CustomStringConvertible {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var description: String {
        message
    }
}
