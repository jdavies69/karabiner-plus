import SwiftUI

struct SafetyView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                updateCard
                writeRulesCard
                privacyCard
                pathsCard
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Safety")
                .font(.largeTitle.weight(.semibold))
            Text("Karabiner+ stays local, preserves unrelated Karabiner rules, and creates backups before each shortcut change.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: 720, alignment: .leading)
        }
    }

    private var updateCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: model.updateAvailable ? "arrow.down.circle.fill" : "arrow.triangle.2.circlepath")
                        .font(.title2)
                        .foregroundStyle(model.updateAvailable ? .orange : .secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Updates")
                            .font(.title3.weight(.semibold))
                        Text(model.updateStatusTitle)
                            .font(.headline)
                        Text(model.updateStatusDetail)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 12) {
                    Button(model.isCheckingForUpdates ? "Checking..." : "Check for Updates") {
                        Task {
                            await model.checkForUpdates()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isCheckingForUpdates)

                    Button("Open GitHub") {
                        model.openProjectOnGitHub()
                    }
                    .buttonStyle(.bordered)

                    Button("Copy Update Command") {
                        model.copyUpdateCommand()
                    }
                    .buttonStyle(.bordered)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Current build")
                        .font(.callout.weight(.semibold))
                    Text("Version \(model.appVersion) · \(model.buildBranch) · \(model.buildCommitShort) · \(model.buildDate)")
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    if model.updateAvailable {
                        Text(model.updateCommand)
                            .font(.callout.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .padding(10)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
    }

    private var writeRulesCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Config Writes")
                    .font(.title3.weight(.semibold))
                bullet("Custom and recommended shortcut writes require an existing ~/.config/karabiner/karabiner.json.")
                bullet("Each apply action creates a timestamped backup before writing.")
                bullet("Create saves the full Karabiner+ Studio shortcut list instead of overwriting one shortcut at a time.")
                bullet("Risky global shortcuts and plain-key remaps are surfaced before apply.")
            }
        }
    }

    private var privacyCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Local Privacy")
                    .font(.title3.weight(.semibold))
                bullet("Coach tracking starts only after you explicitly press Start Tracking.")
                bullet("Tracking runs only while the app is open.")
                bullet("Usage history stays in local UserDefaults on this Mac.")
                bullet("Karabiner+ does not collect keystrokes, window titles, document contents, or cloud data.")
            }
        }
    }

    private var pathsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Paths")
                    .font(.title3.weight(.semibold))
                Text(model.service.configURL.path)
                    .textSelection(.enabled)
                Text(model.service.backupDirectoryURL.path)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
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
}
