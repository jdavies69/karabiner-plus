import Foundation

public struct Recommendation: Equatable, Sendable {
    public let id: String
    public let title: String
    public let summary: String
    public let examples: [String]
    public let bundleIdentifiers: [String]
    public let appNames: [String]

    public init(
        id: String,
        title: String,
        summary: String,
        examples: [String],
        bundleIdentifiers: [String],
        appNames: [String]
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.examples = examples
        self.bundleIdentifiers = bundleIdentifiers
        self.appNames = appNames
    }

    public func matches(appName: String, bundleIdentifier: String) -> Bool {
        if !bundleIdentifier.isEmpty && bundleIdentifiers.contains(where: { $0.caseInsensitiveCompare(bundleIdentifier) == .orderedSame }) {
            return true
        }

        let lowercasedName = appName.lowercased()
        return appNames.contains { lowercasedName.contains($0.lowercased()) }
    }
}

public struct RecommendationEngine: Sendable {
    private let packs: [RecommendationPack] = [
        RecommendationPack(
            recommendation: Recommendation(
                id: "slack",
                title: "Slack",
                summary: "Faster Slack search and channel switching.",
                examples: ["Right Command + K opens Slack search"],
                bundleIdentifiers: ["com.tinyspeck.slackmacgap"],
                appNames: ["slack"]
            ),
            bundleIdentifiers: ["com.tinyspeck.slackmacgap"],
            appNames: ["slack"]
        ),
        RecommendationPack(
            recommendation: Recommendation(
                id: "browser",
                title: "Browsers",
                summary: "Address bar focus for Safari, Chrome, Arc, and Firefox.",
                examples: ["Right Command + L focuses the address bar"],
                bundleIdentifiers: [
                    "com.apple.safari",
                    "com.google.chrome",
                    "company.thebrowser.browser",
                    "org.mozilla.firefox",
                ],
                appNames: ["safari", "chrome", "arc", "firefox"]
            ),
            bundleIdentifiers: [
                "com.apple.safari",
                "com.google.chrome",
                "company.thebrowser.browser",
                "org.mozilla.firefox",
            ],
            appNames: ["safari", "chrome", "arc", "firefox"]
        ),
        RecommendationPack(
            recommendation: Recommendation(
                id: "media",
                title: "Media",
                summary: "Playback controls that work without reaching for the menu bar.",
                examples: ["Right Command + Space toggles play/pause"],
                bundleIdentifiers: ["com.spotify.client", "com.apple.music"],
                appNames: ["spotify", "music", "youtube"]
            ),
            bundleIdentifiers: ["com.spotify.client", "com.apple.music"],
            appNames: ["spotify", "music", "youtube"]
        ),
        RecommendationPack(
            recommendation: Recommendation(
                id: "messages",
                title: "Messages",
                summary: "Small navigation helpers for heavy texting sessions.",
                examples: ["Right Command + F opens search in Messages"],
                bundleIdentifiers: ["com.apple.mobilesms"],
                appNames: ["messages"]
            ),
            bundleIdentifiers: ["com.apple.mobilesms"],
            appNames: ["messages"]
        ),
        RecommendationPack(
            recommendation: Recommendation(
                id: "preview",
                title: "Preview",
                summary: "Document navigation helpers for PDFs and screenshots.",
                examples: ["Right Command + Down Arrow moves to the next page"],
                bundleIdentifiers: ["com.apple.preview"],
                appNames: ["preview"]
            ),
            bundleIdentifiers: ["com.apple.preview"],
            appNames: ["preview"]
        ),
    ]

    public init() {}

    public func recommendations(for entries: [UsageEntry]) -> [Recommendation] {
        packs
            .enumerated()
            .compactMap { pair -> RankedRecommendation? in
                let (index, pack) = pair
                var seconds = 0
                var fitScore = 0

                for entry in entries {
                    guard let multiplier = pack.matchMultiplier(for: entry.app) else {
                        continue
                    }

                    seconds += entry.seconds
                    fitScore += entry.seconds * multiplier
                }

                guard seconds > 0 else {
                    return nil
                }

                return RankedRecommendation(
                    recommendation: pack.recommendation,
                    index: index,
                    seconds: seconds,
                    fitScore: fitScore
                )
            }
            .sorted { left, right in
                if left.seconds != right.seconds {
                    return left.seconds > right.seconds
                }

                if left.fitScore != right.fitScore {
                    return left.fitScore > right.fitScore
                }

                return left.index < right.index
            }
            .map(\.recommendation)
    }
}

private struct RecommendationPack: Sendable {
    let recommendation: Recommendation
    let bundleIdentifiers: Set<String>
    let appNames: Set<String>

    func matchMultiplier(for app: TrackedApp) -> Int? {
        if bundleIdentifiers.contains(app.bundleIdentifier.lowercased()) {
            return 3
        }

        if appNames.contains(app.name.lowercased()) {
            return 2
        }

        return nil
    }
}

private struct RankedRecommendation {
    let recommendation: Recommendation
    let index: Int
    let seconds: Int
    let fitScore: Int
}
