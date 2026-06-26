import AppKit
import SwiftUI

struct StartView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                hero
                nextSteps
                trustStrip
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var hero: some View {
        HStack(alignment: .center, spacing: 22) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 86, height: 86)
                .shadow(color: .black.opacity(0.16), radius: 18, y: 8)

            VStack(alignment: .leading, spacing: 10) {
                Text("Keyboard customization without the Karabiner headache.")
                    .font(.system(size: 34, weight: .semibold))
                    .frame(maxWidth: 760, alignment: .leading)
                Text("Karabiner+ works with the official Karabiner-Elements app you already use. It helps you connect, back up, create safer shortcuts, and get suggestions from your own local app habits.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 820, alignment: .leading)
            }
        }
    }

    private var nextSteps: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Start here")
                .font(.title2.weight(.semibold))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 14)], alignment: .leading, spacing: 14) {
                actionCard(
                    icon: "checklist",
                    title: model.setupHeadline,
                    body: model.setupSubheadline,
                    buttonTitle: model.hasKarabinerConfig ? "Review setup" : "Connect Karabiner",
                    isPrimary: !model.hasKarabinerConfig
                ) {
                    model.navigate(to: .setup)
                }

                actionCard(
                    icon: "plus.square.on.square",
                    title: "Create one shortcut",
                    body: "Start from a safe template, preview the exact remap, then save it with a backup.",
                    buttonTitle: "Open Create",
                    isPrimary: model.hasKarabinerConfig
                ) {
                    model.navigate(to: .studio)
                }

                actionCard(
                    icon: "chart.bar.doc.horizontal",
                    title: "Let Coach watch app usage",
                    body: "Opt in while this app is open, then get shortcut packs for the apps you actually use.",
                    buttonTitle: "Open Coach",
                    isPrimary: false
                ) {
                    model.navigate(to: .coach)
                }
            }
        }
    }

    private var trustStrip: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], alignment: .leading, spacing: 12) {
            trustPill("Uses official Karabiner")
            trustPill("Backs up before writes")
            trustPill("No keystroke tracking")
            trustPill("Local-only history")
        }
    }

    private func actionCard(
        icon: String,
        title: String,
        body: String,
        buttonTitle: String,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
            Text(title)
                .font(.headline)
            Text(body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if isPrimary {
                Button(buttonTitle, action: action)
                    .buttonStyle(.borderedProminent)
            } else {
                Button(buttonTitle, action: action)
                    .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 210, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func trustPill(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.seal")
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
    }
}
