import SwiftUI

struct SetupView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                readinessCard
                actionsCard
                permissionsCard
                advancedCard
                if !model.setupMessage.isEmpty {
                    messageCard(title: "Latest update", message: model.setupMessage)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Connect Karabiner")
                .font(.largeTitle.weight(.semibold))
            Text("Karabiner+ works with the official Karabiner-Elements app. It does not replace the keyboard driver; it gives you a safer setup, backup, and shortcut creation layer.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 760, alignment: .leading)
        }
    }

    private var readinessCard: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: model.hasKarabinerConfig ? "checkmark.circle.fill" : "exclamationmark.circle")
                        .font(.title)
                        .foregroundStyle(model.hasKarabinerConfig ? .green : .orange)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.setupHeadline)
                            .font(.title2.weight(.semibold))
                        Text(model.setupSubheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    checklistRow(
                        done: model.karabinerAppInstalled,
                        title: "Official Karabiner-Elements app",
                        detail: model.karabinerAppInstalled ? "Installed on this Mac" : "Download or install it first"
                    )
                    checklistRow(
                        done: model.hasKarabinerConfig,
                        title: "Karabiner config",
                        detail: model.hasKarabinerConfig ? "Ready to write safely" : "Open Karabiner once to create it"
                    )
                    checklistRow(
                        done: model.setupStatus?.activeProfileName != nil,
                        title: "Active profile",
                        detail: model.setupStatus?.activeProfileName ?? "Unknown until config exists"
                    )
                    checklistRow(
                        done: model.hasKarabinerConfig,
                        title: "Backup protection",
                        detail: model.hasKarabinerConfig ? "Every save creates a backup first" : "Available after config is ready"
                    )
                }
            }
        }
    }

    private var actionsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Next action")
                    .font(.title3.weight(.semibold))

                HStack(spacing: 12) {
                    if model.karabinerAppInstalled {
                        Button("Open Karabiner-Elements") {
                            model.openKarabiner()
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Download Karabiner-Elements") {
                            model.openOfficialDownload()
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Button("Refresh") {
                        model.refreshStatus()
                    }
                    .buttonStyle(.bordered)

                    Button("Create Backup") {
                        model.backupConfig()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!model.hasKarabinerConfig)
                }

                if !model.hasKarabinerConfig {
                    Text("Backup and shortcut buttons unlock after Karabiner-Elements creates its config.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                DisclosureGroup("Advanced install option") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Use this only if you already use Homebrew.")
                            .foregroundStyle(.secondary)
                        Button("Install with Homebrew") {
                            Task {
                                await model.installViaHomebrew()
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.isBusy)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    private var permissionsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                Text("macOS permissions")
                    .font(.title3.weight(.semibold))
                Text("Karabiner-Elements may need Accessibility and Input Monitoring approval. Karabiner+ can open the right Settings pages, but macOS requires you to approve them.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Button("Open Accessibility") {
                        model.openAccessibilitySettings()
                    }
                    .buttonStyle(.bordered)

                    Button("Open Input Monitoring") {
                        model.openInputMonitoringSettings()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var advancedCard: some View {
        card {
            DisclosureGroup("Advanced paths") {
                VStack(alignment: .leading, spacing: 10) {
                    statusRow(label: "Config", value: model.service.configURL.path)
                    statusRow(label: "Backups", value: model.service.backupDirectoryURL.path)
                    statusRow(label: "Homebrew", value: model.homebrewAvailable ? "Available" : "Not installed")
                }
                .padding(.top, 8)
            }
        }
    }

    private func checklistRow(done: Bool, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? .green : .secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func statusRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 88, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
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
