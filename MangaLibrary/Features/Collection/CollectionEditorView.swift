//
//  CollectionEditorView.swift
//  MangaLibrary
//

import SwiftData
import SwiftUI

struct CollectionEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var model: CollectionEditorModel
    @State private var request: SubmissionRequest?
    @State private var confirmsDeletion = false

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            Form {
                if let title = model.seed.title {
                    Section {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.textPrimary)
                    }
                } else {
                    Section {
                        Text("Manga #\(model.seed.identity.mangaID)")
                            .font(.headline)
                            .foregroundStyle(.textPrimary)
                    }
                }

                ownedVolumesSection
                readingProgressSection
                completionSection

                if let message = failureMessage {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.dangerInk)
                            .accessibilityIdentifier("collection.editor.error")
                    }
                }

                if model.seed.isExistingEntry {
                    Section {
                        Button("Remove from Collection", systemImage: "trash", role: .destructive) {
                            confirmsDeletion = true
                        }
                        .disabled(model.isSubmitting)
                        .accessibilityIdentifier("collection.editor.delete")
                    }
                }
            }
            .disabled(model.isSubmitting)
            .overlay {
                if let submissionProgressTitle {
                    ProgressView(submissionProgressTitle)
                        .padding()
                        .background(.surface, in: .rect(cornerRadius: 12))
                        .accessibilityIdentifier("collection.editor.progress")
                }
            }
            .navigationTitle("Collection")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(model.isSubmitting)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", role: .cancel) {
                        dismiss()
                    }
                    .labelStyle(.iconOnly)
                    .disabled(model.isSubmitting)
                    .accessibilityLabel("Cancel")
                    .accessibilityIdentifier("collection.editor.cancel")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        request = .save(UUID())
                    } label: {
                        if model.submissionState == .saving {
                            ProgressView()
                        } else {
                            Label("Save", systemImage: "checkmark")
                        }
                    }
                    .labelStyle(.iconOnly)
                    .disabled(model.canSave == false)
                    .accessibilityLabel("Save")
                    .accessibilityIdentifier("collection.editor.save")
                }
            }
            .confirmationDialog(
                "Remove this manga from your collection?",
                isPresented: $confirmsDeletion,
                titleVisibility: .visible
            ) {
                Button("Remove from Collection", role: .destructive) {
                    request = .delete(UUID())
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The manga disappears now. Its pending deletion remains stored for later synchronization.")
            }
            .task(id: request) {
                guard let request else { return }

                let didFinish = switch request {
                case .save:
                    await model.save()
                case .delete:
                    await model.delete()
                }
                if didFinish {
                    dismiss()
                }
            }
        }
    }

    private var ownedVolumesSection: some View {
        Section("Owned volumes") {
            if let total = model.knownTotalVolumes {
                ForEach(Int64(1)...total, id: \.self) { volume in
                    Toggle(
                        "Volume \(volume)",
                        isOn: Binding {
                            model.owns(volume: volume)
                        } set: { ownsVolume in
                            model.setOwned(ownsVolume, volume: volume)
                        }
                    )
                    .accessibilityIdentifier("collection.editor.owned-volume.\(volume)")
                }
            } else {
                Text("The catalog does not publish a total. Add each volume number you own.")
                    .font(.footnote)
                    .foregroundStyle(.textSecondary)

                HStack(alignment: .firstTextBaseline) {
                    TextField("Volume number", text: $model.volumeInput)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("collection.editor.volume-input")

                    Button("Add", systemImage: "plus") {
                        model.addUnknownVolume()
                    }
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
                    .accessibilityLabel("Add volume")
                    .accessibilityIdentifier("collection.editor.volume-add")
                }

                if model.sortedOwnedVolumes.isEmpty {
                    Text("No owned volumes selected")
                        .foregroundStyle(.textSecondary)
                } else {
                    ForEach(model.sortedOwnedVolumes, id: \.self) { volume in
                        HStack {
                            Text("Volume \(volume)")
                            Spacer()
                            Button("Remove volume \(volume)", systemImage: "minus.circle", role: .destructive) {
                                model.removeOwnedVolume(volume)
                            }
                            .labelStyle(.iconOnly)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(.rect)
                            .accessibilityIdentifier("collection.editor.owned.remove.\(volume)")
                        }
                    }
                }
            }

            if model.inputFailure == .invalidOwnedVolume {
                Text("Enter a positive whole volume number.")
                    .font(.footnote)
                    .foregroundStyle(.dangerInk)
                    .accessibilityIdentifier("collection.editor.volume-error")
            } else if model.inputFailure == .pendingOwnedVolume {
                Text("Add or clear the pending volume before saving.")
                    .font(.footnote)
                    .foregroundStyle(.dangerInk)
                    .accessibilityIdentifier("collection.editor.volume-error")
            }
        }
    }

    private var readingProgressSection: some View {
        Section("Reading progress") {
            if let total = model.knownTotalVolumes {
                Picker("Current volume", selection: readingVolumeSelection) {
                    Text("Not set").tag(Int64?.none)
                    ForEach(Int64(1)...total, id: \.self) { volume in
                        Text("Volume \(volume)").tag(Int64?.some(volume))
                    }
                }
                .accessibilityIdentifier("collection.editor.reading-picker")
            } else {
                TextField("Current volume (optional)", text: readingVolumeText)
                    .keyboardType(.numberPad)
                    .accessibilityIdentifier("collection.editor.reading-input")
            }

            if model.inputFailure == .invalidReadingVolume {
                Text("Enter a positive whole volume number within the known total.")
                    .font(.footnote)
                    .foregroundStyle(.dangerInk)
                    .accessibilityIdentifier("collection.editor.reading-error")
            }
        }
    }

    private var completionSection: some View {
        Section {
            Toggle(
                "Complete collection",
                isOn: Binding {
                    model.isComplete
                } set: { complete in
                    model.setComplete(complete)
                }
            )
            .disabled(model.knownTotalVolumes == nil)
            .accessibilityIdentifier("collection.editor.complete")

            if model.knownTotalVolumes == nil {
                Text("A published total is required before marking the collection complete.")
                    .font(.footnote)
                    .foregroundStyle(.textSecondary)
            }
        }
    }

    private var readingVolumeSelection: Binding<Int64?> {
        Binding {
            Int64(model.readingVolumeText)
        } set: { volume in
            model.readingVolumeText = volume.map(String.init) ?? ""
        }
    }

    private var readingVolumeText: Binding<String> {
        Binding {
            model.readingVolumeText
        } set: { value in
            model.readingVolumeText = value
        }
    }

    private var failureMessage: LocalizedStringResource? {
        guard case let .failed(error) = model.submissionState else { return nil }

        return error.errorDescriptionResource
    }

    private var submissionProgressTitle: LocalizedStringResource? {
        switch model.submissionState {
        case .saving:
            "Saving collection"
        case .deleting:
            "Removing from collection"
        case .idle, .failed:
            nil
        }
    }
}

extension CollectionEditorView {
    init(seed: CollectionEditorSeed, mutation: CollectionMutation) {
        _model = State(initialValue: CollectionEditorModel(seed: seed, mutation: mutation))
    }
}

private enum SubmissionRequest: Hashable {
    case save(UUID)
    case delete(UUID)
}

#Preview(
    "Known total editor",
    traits: .modifier(CollectionPreviewModifier<CollectionPreviewScenarios.KnownTotalEditor>())
) {
    @Previewable @Environment(\.modelContext) var modelContext
    CollectionPreviewSupport.knownTotalEditor(container: modelContext.container)
}

#Preview(
    "Unknown total editor",
    traits: .modifier(CollectionPreviewModifier<CollectionPreviewScenarios.UnknownTotalEditor>())
) {
    @Previewable @Environment(\.modelContext) var modelContext
    CollectionPreviewSupport.unknownTotalEditor(container: modelContext.container)
}
