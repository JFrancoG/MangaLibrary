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

                if model.isVolumeStateEditable {
                    ownedVolumesSection
                    readingProgressSection
                    completionSection
                }

                if let message = failureMessage {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.dangerInk)
                            .accessibilityIdentifier("collection.editor.error")
                    }
                }

                if model.seed.isExistingEntry {
                    Section {
                        Button("Remove from Collection", role: .destructive) {
                            confirmsDeletion = true
                        }
                        .font(.headline)
                        .foregroundStyle(.onDanger)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .buttonSizing(.fitted)
                        .tint(Color.dangerFill)
                        .frame(maxWidth: .infinity)
                        .disabled(model.isSubmitting)
                        .accessibilityIdentifier("collection.editor.delete")
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
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
            .alert(deletionAlertTitle, isPresented: $confirmsDeletion) {
                Button("Remove", role: .destructive) {
                    request = .delete(UUID())
                }
                .accessibilityIdentifier("collection.editor.delete.confirm")

                Button("Cancel", role: .cancel) {}
                    .accessibilityIdentifier("collection.editor.delete.cancel")
            } message: {
                Text(
                    """
                    The volumes marked as owned and your reading progress will be deleted. \
                    You can add the manga again, but that data won’t be restored.
                    """
                )
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
            if let knownVolumeNumbers = model.knownVolumeNumbers {
                ForEach(knownVolumeNumbers, id: \.self) { volume in
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

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Volume number", text: $model.volumeInput)
                            .keyboardType(.numberPad)
                            .accessibilityIdentifier("collection.editor.volume-input")

                        Button("Add volume", systemImage: "plus") {
                            model.addUnknownVolume()
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .controlSize(.large)
                        .tint(Color.brandPrimary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(.rect)
                        .accessibilityIdentifier("collection.editor.volume-add")
                    }

                    if model.inputFailure == .invalidOwnedVolume {
                        Text("Enter a whole volume number from 1 to \(CollectionVolumePolicy.maximum).")
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

                if model.sortedOwnedVolumes.isEmpty {
                    Text("No owned volumes selected")
                        .foregroundStyle(.textSecondary)
                } else {
                    ForEach(model.sortedOwnedVolumes, id: \.self) { volume in
                        HStack {
                            Text("Volume \(volume)")
                            Spacer()
                            Button("Remove volume \(volume)", systemImage: "trash", role: .destructive) {
                                model.removeOwnedVolume(volume)
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.circle)
                            .controlSize(.large)
                            .tint(Color.dangerFill)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(.rect)
                            .accessibilityIdentifier("collection.editor.owned.remove.\(volume)")
                        }
                    }
                }
            }
        }
    }

    private var readingProgressSection: some View {
        Section("Reading progress") {
            if let knownVolumeNumbers = model.knownVolumeNumbers {
                Picker("Current volume", selection: readingVolumeSelection) {
                    Text("Not set").tag(Int64?.none)
                    ForEach(knownVolumeNumbers, id: \.self) { volume in
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
                Text("Enter a whole volume number from 1 to \(CollectionVolumePolicy.maximum).")
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
            .disabled(model.knownVolumeNumbers == nil)
            .accessibilityIdentifier("collection.editor.complete")

            if model.knownVolumeNumbers == nil {
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

    private var deletionAlertTitle: LocalizedStringResource {
        if let title = model.seed.title {
            "Remove “\(title)” from your collection?"
        } else {
            "Remove this manga from your collection?"
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

#Preview(
    "Historical incompatible editor",
    traits: .modifier(CollectionPreviewModifier<CollectionPreviewScenarios.HistoricalIncompatibleEditor>())
) {
    @Previewable @Environment(\.modelContext) var modelContext
    CollectionPreviewSupport.historicalIncompatibleEditor(container: modelContext.container)
}
