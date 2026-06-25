import Foundation

public struct TrackedApp: Hashable, Equatable, Sendable {
    public let name: String
    public let bundleIdentifier: String

    public init(name: String, bundleIdentifier: String) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
    }
}

public struct UsageEntry: Equatable, Sendable {
    public let app: TrackedApp
    public let seconds: Int

    public init(app: TrackedApp, seconds: Int) {
        self.app = app
        self.seconds = seconds
    }
}

public struct UsageAccumulator: Sendable {
    private var totals: [TrackedApp: TimeInterval] = [:]
    private var lastObservation: (app: TrackedApp, timestamp: Date)?

    public init() {}

    public mutating func record(app: TrackedApp, at timestamp: Date) {
        if let lastObservation, timestamp >= lastObservation.timestamp {
            let elapsed = timestamp.timeIntervalSince(lastObservation.timestamp)
            totals[lastObservation.app, default: 0] += elapsed
        }

        lastObservation = (app, timestamp)
    }

    public var entries: [UsageEntry] {
        totals
            .map { app, seconds in
                UsageEntry(app: app, seconds: Int(seconds.rounded()))
            }
            .sorted { left, right in
                if left.seconds != right.seconds {
                    return left.seconds > right.seconds
                }

                return left.app.name.localizedCaseInsensitiveCompare(right.app.name) == .orderedAscending
            }
    }
}
