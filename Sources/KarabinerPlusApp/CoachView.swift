import SwiftUI

struct CoachView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                disclosureCard
                controlsCard
                recommendationsCard
                historyCard
                if !model.coachMessage.isEmpty {
                    infoCard(title: "Coach Status", message: model.coachMessage)
                }
                if !model.trackingError.isEmpty {
                    infoCard(title: "Tracking Error", message: model.trackingError)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Coach")
                .font(.largeTitle.weight(.semibold))
            Text("Track frontmost apps only while Karabiner+ is open and you have explicitly started tracking.")
                .foregroundStyle(.secondary)
        }
    }

    private var disclosureCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Disclosure")
                    .font(.title3.weight(.semibold))
                Text(model.trackingDisclosure)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var controlsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Tracking")
                    .font(.title3.weight(.semibold))

                HStack(spacing: 12) {
                    Button(model.isTracking ? "Pause Tracking" : "Start Tracking") {
                        if model.isTracking {
                            model.pauseTracking()
                        } else {
                            model.startTracking()
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Delete History") {
                        model.deleteHistory()
                    }
                    .buttonStyle(.bordered)

                    Text(model.isTracking ? "Tracking now" : "Paused")
                        .foregroundStyle(model.isTracking ? .primary : .secondary)
                }
            }
        }
    }

    private var recommendationsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Recommended Packs")
                    .font(.title3.weight(.semibold))

                if model.recommendedPacks.isEmpty {
                    Text("Start tracking to build local usage history and unlock app-aware recommendations.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.recommendedPacks, id: \.id) { recommendation in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(recommendation.title)
                                    .font(.headline)
                                Text(recommendation.summary)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 16)

                            Button("Apply") {
                                model.applyRecommendation(recommendation)
                            }
                            .buttonStyle(.bordered)
                            .disabled(model.setupStatus?.configExists != true)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private var historyCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Top Apps")
                    .font(.title3.weight(.semibold))

                if model.usageRecords.isEmpty {
                    Text("No local usage history yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.usageRecords) { record in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(record.name)
                                    .font(.headline)
                                Spacer()
                                Text(model.formatDuration(record.seconds))
                                    .foregroundStyle(.secondary)
                            }

                            if !record.bundleIdentifier.isEmpty {
                                Text(record.bundleIdentifier)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }

                            Text("Last seen \(model.formatLastSeen(record.lastSeen))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: 820, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }

    private func infoCard(title: String, message: String) -> some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }
}
