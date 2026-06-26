import KarabinerPlusCore
import SwiftUI

struct StudioView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if !model.hasKarabinerConfig {
                    setupGate
                }
                templatesCard
                editorCard
                previewCard
                savedShortcutsCard
                if !model.studioMessage.isEmpty {
                    infoCard(title: "Latest update", message: model.studioMessage)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Create Shortcuts")
                .font(.largeTitle.weight(.semibold))
            Text("Make one key or key combination behave like another. Karabiner+ previews the remap, checks obvious risks, and backs up your config before saving.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 820, alignment: .leading)
        }
    }

    private var setupGate: some View {
        card {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "lock.circle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Finish Connect first")
                        .font(.headline)
                    Text("Karabiner+ needs an existing Karabiner config before it can save shortcuts.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Go to Connect") {
                    model.navigate(to: .setup)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var templatesCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Start from a safe pattern")
                    .font(.title3.weight(.semibold))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 12)], alignment: .leading, spacing: 12) {
                    ForEach(model.shortcutTemplates) { template in
                        Button {
                            model.useTemplate(template)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(template.title)
                                    .font(.headline)
                                Text(template.summary)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    private var editorCard: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Build a remap")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Button("Reset") {
                        model.resetDraft()
                    }
                    .buttonStyle(.bordered)
                }

                TextField("Name this shortcut", text: $model.draft.name)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 360)

                HStack(alignment: .top, spacing: 28) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("When I press")
                            .font(.headline)
                        keyPicker(title: "Key", selection: $model.draft.sourceKey)
                        captureControls(for: .source)
                        modifierGrid(title: "Held with it", modifiers: $model.draft.sourceModifiers)
                    }

                    Image(systemName: "arrow.right")
                        .font(.title2.weight(.semibold))
                        .padding(.top, 36)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Make it act like")
                            .font(.headline)
                        keyPicker(title: "Key", selection: $model.draft.outputKey)
                        captureControls(for: .output)
                        modifierGrid(title: "Keys sent with it", modifiers: $model.draft.outputModifiers)
                    }
                }

                HStack(spacing: 12) {
                    Button("Save Shortcut") {
                        model.applyShortcutDraft()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.draftCanApply)

                    Text(model.draftCanApply ? "A backup will be created first." : disabledReason)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
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
                    .font(.headline)

                Text("Applies everywhere on this Mac in the \(model.setupStatus?.activeProfileName ?? "active") Karabiner profile.")
                    .foregroundStyle(.secondary)

                if definition.isNoOp {
                    Label("This does not change anything because both sides are the same.", systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                } else if model.draftWarnings.isEmpty {
                    Label("No obvious risk warnings for this remap.", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                } else {
                    ForEach(model.draftWarnings, id: \.message) { warning in
                        Label(warning.message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    private var savedShortcutsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Saved Studio shortcuts")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Text("\(model.savedShortcuts.count)")
                        .foregroundStyle(.secondary)
                }

                if model.savedShortcuts.isEmpty {
                    Text("No custom Studio shortcuts yet. Saving one here will preserve future Studio shortcuts in this list.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.savedShortcuts, id: \.name) { definition in
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(definition.name)
                                    .font(.headline)
                                Text(model.preview(for: definition))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Load") {
                                model.draft = AppModel.ShortcutDraft(
                                    name: definition.name,
                                    sourceKey: definition.sourceKey,
                                    sourceModifiers: Set(definition.sourceModifiers),
                                    outputKey: definition.outputKey,
                                    outputModifiers: Set(definition.outputModifiers)
                                )
                            }
                            .buttonStyle(.bordered)

                            Button("Remove") {
                                model.deleteShortcut(definition)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
    }

    private var disabledReason: String {
        if !model.hasKarabinerConfig {
            return "Finish Connect first."
        }

        if model.draft.definition.name.isEmpty {
            return "Name the shortcut first."
        }

        if model.draft.definition.isNoOp {
            return "Choose a different output."
        }

        return "Review the shortcut before saving."
    }

    private func keyPicker(title: String, selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .foregroundStyle(.secondary)
            Picker(title, selection: selection) {
                ForEach(model.keyOptions, id: \.self) { key in
                    Text(model.label(forKey: key)).tag(key)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 190, alignment: .leading)
        }
    }

    private func modifierGrid(title: String, modifiers: Binding<Set<String>>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .foregroundStyle(.secondary)

            ForEach(model.modifierOptions, id: \.self) { modifier in
                Toggle(
                    model.label(forModifier: modifier),
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
        .frame(width: 190, alignment: .leading)
    }

    private func captureControls(for target: AppModel.CaptureTarget) -> some View {
        HStack(spacing: 8) {
            Button(model.captureTarget == target ? "Listening..." : "Capture") {
                model.beginShortcutCapture(target)
            }
            .buttonStyle(.bordered)
            .disabled(model.captureTarget == target)

            if model.captureTarget == target {
                Button("Cancel") {
                    model.cancelShortcutCapture()
                }
                .buttonStyle(.borderless)
            }
        }
        .frame(width: 190, alignment: .leading)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: 900, alignment: .leading)
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
