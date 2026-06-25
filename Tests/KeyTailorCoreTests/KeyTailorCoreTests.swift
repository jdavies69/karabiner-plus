import XCTest
@testable import KeyTailorCore

final class KeyTailorCoreTests: XCTestCase {
    func testBuildCustomRuleProducesKarabinerCompatibleJSON() throws {
        let definition = ShortcutDefinition(
            name: "Launch Terminal",
            sourceKey: "j",
            sourceModifiers: ["command", "shift"],
            outputKey: "escape",
            outputModifiers: []
        )

        let rule = ShortcutRuleBuilder.buildCustomRule(definition)
        let payload = try jsonObject(rule)
        let dictionary = try XCTUnwrap(payload as? [String: Any])
        XCTAssertEqual(dictionary["description"] as? String, "[KeyTailor] Custom: Launch Terminal")
        let manipulators = try XCTUnwrap(dictionary["manipulators"] as? [[String: Any]])
        XCTAssertEqual(manipulators.count, 1)

        let manipulator = manipulators[0]
        XCTAssertEqual(manipulator["type"] as? String, "basic")

        let from = try XCTUnwrap(manipulator["from"] as? [String: Any])
        XCTAssertEqual(from["key_code"] as? String, "j")

        let modifiers = try XCTUnwrap(from["modifiers"] as? [String: Any])
        XCTAssertEqual(modifiers["mandatory"] as? [String], ["command", "shift"])
        XCTAssertEqual(modifiers["optional"] as? [String], ["any"])

        let to = try XCTUnwrap(manipulator["to"] as? [[String: Any]])
        XCTAssertEqual(to.count, 1)
        XCTAssertEqual(to[0]["key_code"] as? String, "escape")
        XCTAssertNil(to[0]["modifiers"])
    }

    func testCommandQProducesRiskWarning() {
        let definition = ShortcutDefinition(
            name: "Replace Quit",
            sourceKey: "q",
            sourceModifiers: ["command"],
            outputKey: "escape",
            outputModifiers: []
        )

        XCTAssertEqual(definition.warnings, [
            ShortcutWarning(message: "Command-Q is a risky macOS shortcut and may override a common system action.")
        ])
    }

    func testUsageAccumulatorAggregatesElapsedTimeByApp() {
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

        XCTAssertEqual(accumulator.entries, [
            UsageEntry(app: TrackedApp(name: "Slack", bundleIdentifier: "com.tinyspeck.slackmacgap"), seconds: 180),
            UsageEntry(app: TrackedApp(name: "Safari", bundleIdentifier: "com.apple.Safari"), seconds: 180),
        ])
    }

    func testRecommendationsRankSlackAheadOfBrowserAndMediaUsage() {
        let engine = RecommendationEngine()
        let entries = [
            UsageEntry(app: TrackedApp(name: "Slack", bundleIdentifier: "com.tinyspeck.slackmacgap"), seconds: 240),
            UsageEntry(app: TrackedApp(name: "Safari", bundleIdentifier: "com.apple.Safari"), seconds: 180),
            UsageEntry(app: TrackedApp(name: "Spotify", bundleIdentifier: "com.spotify.client"), seconds: 60),
        ]

        XCTAssertEqual(
            engine.recommendations(for: entries).map(\.id),
            ["slack", "browser", "media"]
        )
    }

    private func jsonObject<T: Encodable>(_ value: T) throws -> Any {
        let data = try JSONEncoder().encode(value)
        return try JSONSerialization.jsonObject(with: data)
    }
}
