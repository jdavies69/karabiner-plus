import SwiftUI

struct SetupView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                statusCard
                actionsCard
                if !model.setupMessage.isEmpty {
                    messageCard(title: "Setup Status", message: model.setupMessage)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Setup")
                .font(.largeTitle.weight(.semibold))
            Text("Check the local Karabiner configuration, install the official app, and make a backup before changing shortcuts.")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 720, alignment: .leading)
        }
    }

    private var statusCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Local Status")
                    .font(.title3.weight(.semibold))

                statusRow(label: "Karabiner config", value: model.setupStatus?.configExists == true ? "Found" : "Missing")
                statusRow(label: "Active profile", value: model.setupStatus?.activeProfileName ?? "Unknown")
                statusRow(label: "Homebrew", value: model.homebrewAvailable ? "Available" : "Not found")
                statusRow(label: "Config path", value: model.service.configURL.path)
            }
        }
    }

    private var actionsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Actions")
                    .font(.title3.weight(.semibold))

                HStack(spacing: 12) {
                    Button("Refresh") {
                        model.refreshStatus()
                    }
                    .buttonStyle(.bordered)

                    Button("Install via Homebrew") {
                        Task {
                            await model.installViaHomebrew()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isBusy)

                    Button("Open Official Download") {
                        model.openOfficialDownload()
                    }
                    .buttonStyle(.bordered)
                }

                HStack(spacing: 12) {
                    Button("Open Karabiner") {
                        model.openKarabiner()
                    }
                    .buttonStyle(.bordered)

                    Button("Backup Config") {
                        model.backupConfig()
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.setupStatus?.configExists != true)
                }
            }
        }
    }

    private func statusRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: 760, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }

    private func messageCard(title: String, message: String) -> some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .textSelection(.enabled)
            }
        }
    }
}
