import SwiftUI

struct CoachView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                trackingCard
                recommendationsCard
                historyCard
                if !model.coachMessage.isEmpty {
                    infoCard(title: "Latest update", message: model.coachMessage)
                }
                if !model.trackingError.isEmpty {
                    infoCard(title: "Tracking issue", message: model.trackingError)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Shortcut Coach")
                .font(.largeTitle.weight(.semibold))
            Text("Let Karabiner+ observe which app is frontmost while this window is open. It turns that local history into shortcut packs worth trying.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 820, alignment: .leading)
        }
    }

    private var trackingCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: model.isTracking ? "dot.radiowaves.left.and.right" : "hand.raised")
                        .font(.title2)
                        .foregroundStyle(model.isTracking ? .green : .secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.isTracking ? "Tracking while Karabiner+ is open" : "Tracking is off")
                            .font(.title3.weight(.semibold))
                        Text(model.trackingDisclosure)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 12) {
                    Button(model.isTracking ? "Pause Tracking" : "Start Tracking") {
                        if model.isTracking {
                            model.pauseTracking()
                        } else {
                            model.startTracking()
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Delete Local History") {
                        model.deleteHistory()
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.usageRecords.isEmpty && !model.isTracking)
                }

                Text("No keystrokes, window titles, document names, or cloud data. You can delete the local history anytime.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var recommendationsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Recommended packs")
                    .font(.title3.weight(.semibold))

                if model.recommendedPacks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No recommendations yet.")
                            .font(.headline)
                        Text("Start tracking, use your Mac normally for a few minutes, then come back here. Coach will rank packs for apps like Slack, browsers, Messages, Preview, and media apps.")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    ForEach(model.recommendedPacks, id: \.id) { recommendation in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(recommendation.title)
                                        .font(.headline)
                                    Text(recommendation.summary)
                                        .foregroundStyle(.secondary)
                                    Text(model.reason(for: recommendation))
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer(minLength: 16)

                                Button("Apply Pack") {
                                    model.applyRecommendation(recommendation)
                                }
                                .buttonStyle(.bordered)
                                .disabled(!model.hasKarabinerConfig)
                            }

                            ForEach(recommendation.examples, id: \.self) { example in
                                Label(example, systemImage: "sparkle")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }

                            if !model.hasKarabinerConfig {
                                Button("Go to Connect") {
                                    model.navigate(to: .setup)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 8)

                        if recommendation.id != model.recommendedPacks.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var historyCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Local app history")
                    .font(.title3.weight(.semibold))

                if model.usageRecords.isEmpty {
                    Text("Nothing recorded yet. Tracking only runs after you start it and only while Karabiner+ stays open.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.usageRecords.prefix(8)) { record in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(record.name)
                                    .font(.headline)
                                Spacer()
                                Text(model.formatDuration(record.seconds))
                                    .foregroundStyle(.secondary)
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
            .frame(maxWidth: 860, alignment: .leading)
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
