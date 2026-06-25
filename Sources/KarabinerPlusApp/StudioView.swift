import KarabinerPlusCore
import SwiftUI

struct StudioView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                editorCard
                previewCard
                if !model.studioMessage.isEmpty {
                    infoCard(title: "Studio Status", message: model.studioMessage)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Studio")
                .font(.largeTitle.weight(.semibold))
            Text("Create global shortcuts only for V1, preview the remap, and apply it through the Karabiner config service.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: 720, alignment: .leading)
        }
    }

    private var editorCard: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                Text("Shortcut Definition")
                    .font(.title3.weight(.semibold))

                TextField("Shortcut name", text: $model.draft.name)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 320)

                HStack(alignment: .top, spacing: 20) {
                    keyPicker(title: "Source key", selection: $model.draft.sourceKey)
                    modifierGrid(title: "Source modifiers", modifiers: $model.draft.sourceModifiers)
                }

                HStack(alignment: .top, spacing: 20) {
                    keyPicker(title: "Output key", selection: $model.draft.outputKey)
                    modifierGrid(title: "Output modifiers", modifiers: $model.draft.outputModifiers)
                }

                Button("Apply Global Shortcut") {
                    model.applyShortcutDraft()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.setupStatus?.configExists != true)
            }
        }
    }

    private var previewCard: some View {
        let definition = model.draft.definition

        return card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Preview")
                    .font(.title3.weight(.semibold))
                Text(model.draft.preview)
                    .font(.body.monospaced())

                if definition.warnings.isEmpty {
                    Text("No risky global Command shortcut warnings for this source combination.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(definition.warnings, id: \.message) { warning in
                        Label(warning.message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }

    private func keyPicker(title: String, selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .foregroundStyle(.secondary)
            Picker(title, selection: selection) {
                ForEach(model.keyOptions, id: \.self) { key in
                    Text(key.replacingOccurrences(of: "_", with: " ").capitalized).tag(key)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 180, alignment: .leading)
        }
    }

    private func modifierGrid(title: String, modifiers: Binding<Set<String>>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .foregroundStyle(.secondary)

            ForEach(model.modifierOptions, id: \.self) { modifier in
                Toggle(
                    modifier.capitalized,
                    isOn: Binding(
                        get: { modifiers.wrappedValue.contains(modifier) },
                        set: { enabled in
                            if enabled {
                                modifiers.wrappedValue.insert(modifier)
                            } else {
                                modifiers.wrappedValue.remove(modifier)
                            }
                        }
                    )
                )
                .toggleStyle(.checkbox)
            }
        }
        .frame(width: 180, alignment: .leading)
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
