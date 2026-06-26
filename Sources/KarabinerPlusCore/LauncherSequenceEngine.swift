import Foundation

public struct LauncherSequenceSuggestion: Equatable, Identifiable, Sendable {
    public let definition: LauncherSequenceDefinition
    public let seconds: Int

    public var id: String {
        definition.id
    }

    public init(definition: LauncherSequenceDefinition, seconds: Int) {
        self.definition = definition
        self.seconds = seconds
    }
}

public struct LauncherSequenceEngine: Sendable {
    public init() {}

    public func suggestions(for entries: [UsageEntry]) -> [LauncherSequenceSuggestion] {
        var selectedDefinitions: [LauncherSequenceDefinition] = []
        var suggestions: [LauncherSequenceSuggestion] = []

        for entry in entries.sorted(by: usageSort) {
            let app = entry.app
            guard !app.bundleIdentifier.isEmpty, entry.seconds > 0 else {
                continue
            }

            guard let definition = definition(for: app, selectedDefinitions: selectedDefinitions) else {
                continue
            }

            selectedDefinitions.append(definition)
            suggestions.append(
                LauncherSequenceSuggestion(
                    definition: definition,
                    seconds: entry.seconds
                )
            )
        }

        return suggestions
    }

    private func definition(
        for app: TrackedApp,
        selectedDefinitions: [LauncherSequenceDefinition]
    ) -> LauncherSequenceDefinition? {
        for candidate in sequenceCandidates(for: app) {
            let definition = LauncherSequenceDefinition(
                appName: displayName(for: app),
                bundleIdentifier: app.bundleIdentifier,
                sequence: candidate
            )

            if LauncherSequenceRuleBuilder.validationIssues(for: selectedDefinitions + [definition]).isEmpty {
                return definition
            }
        }

        return nil
    }

    private func sequenceCandidates(for app: TrackedApp) -> [[String]] {
        var candidates: [[String]] = []
        var seen = Set<String>()

        func appendCandidate(_ candidate: [String]) {
            let normalized = Array(candidate
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
                .prefix(2))

            guard !normalized.isEmpty else {
                return
            }

            let key = normalized.joined()
            guard seen.insert(key).inserted else {
                return
            }

            candidates.append(normalized)
        }

        let appWords = words(in: app.name)
        let preferredWords = appWords.filter { !Self.companyOrWrapperWords.contains($0) }

        if let productWord = productWord(for: app) {
            appendCandidate(firstTwoCharacters(in: productWord))
        }

        for word in preferredWords + appWords {
            appendCandidate(firstTwoCharacters(in: word))
        }

        let bundleLeaf = app.bundleIdentifier
            .split(separator: ".")
            .last
            .map(String.init)
            .map { self.words(in: $0).joined() }

        if let bundleLeaf {
            appendCandidate(firstTwoCharacters(in: bundleLeaf))
        }

        if appWords.count >= 2 {
            appendCandidate(appWords.prefix(2).compactMap(\.first).map(String.init))
        }

        for word in preferredWords + appWords {
            for candidate in firstCharacterPlusFollowingCharacters(in: word) {
                appendCandidate(candidate)
            }
        }

        for word in preferredWords + appWords {
            appendCandidate(firstOneCharacter(in: word))
        }

        return candidates
    }

    private func displayName(for app: TrackedApp) -> String {
        productDisplayName(for: app) ?? app.name
    }

    private func productDisplayName(for app: TrackedApp) -> String? {
        let bundleIdentifier = app.bundleIdentifier.lowercased()
        let appName = app.name.lowercased()

        if bundleIdentifier.contains("codex") || appName == "codex" {
            return "Codex"
        }

        if bundleIdentifier.contains("chatgpt") || appName.contains("chatgpt") {
            return "ChatGPT"
        }

        if bundleIdentifier.contains("superhuman") || appName.contains("superhuman") {
            return "Superhuman"
        }

        return nil
    }

    private func productWord(for app: TrackedApp) -> String? {
        productDisplayName(for: app).map { words(in: $0).joined() }
    }

    private func words(in value: String) -> [String] {
        value
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private func firstTwoCharacters(in value: String) -> [String] {
        Array(value.map(String.init).prefix(2))
    }

    private func firstOneCharacter(in value: String) -> [String] {
        Array(value.map(String.init).prefix(1))
    }

    private func firstCharacterPlusFollowingCharacters(in value: String) -> [[String]] {
        let characters = value.map(String.init)
        guard let first = characters.first else {
            return []
        }

        return characters.dropFirst().map { [first, $0] }
    }

    private func usageSort(_ left: UsageEntry, _ right: UsageEntry) -> Bool {
        if left.seconds != right.seconds {
            return left.seconds > right.seconds
        }

        return left.app.name.localizedCaseInsensitiveCompare(right.app.name) == .orderedAscending
    }

    private static let companyOrWrapperWords: Set<String> = [
        "apple",
        "browser",
        "company",
        "google",
        "inc",
        "microsoft",
        "openai",
        "the",
    ]
}
