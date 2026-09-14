//
//  CollectionBlockedOutcomeReviewView.swift
//  MangaLibrary
//

import SwiftUI

struct CollectionBlockedOutcomeReviewView: View {
    private enum Request: Equatable {
        case review(UUID)
        case resolve(UUID, CollectionBlockedOutcomeDecision)
    }

    @Environment(\.dismiss) private var dismiss

    @State private var model: CollectionBlockedOutcomeReviewModel
    @State private var request: Request?
    @State private var proposedDecision: CollectionBlockedOutcomeDecision?

    init(
        operationID: UUID,
        authority: SessionAuthority,
        resolution: CollectionBlockedOutcomeResolution,
        initialState: CollectionBlockedOutcomeReviewModel.State = .idle
    ) {
        _model = State(
            initialValue: CollectionBlockedOutcomeReviewModel(
                operationID: operationID,
                authority: authority,
                resolution: resolution,
                initialState: initialState
            )
        )
    }

    var body: some View {
        content
            .background(.canvas)
            .navigationTitle("Review change")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await model.reviewIfNeeded()
            }
            .task(id: request) {
                guard let request else { return }

                switch request {
                case .review:
                    await model.review()
                case let .resolve(_, decision):
                    if await model.resolve(decision) {
                        dismiss()
                    }
                }
            }
            .alert("Confirm your choice", item: $proposedDecision) { decision in
                Button(decision.actionTitle, role: .destructive) {
                    request = .resolve(UUID(), decision)
                }
                .accessibilityIdentifier("collection.blocked-outcome.confirm")

                Button("Cancel", role: .cancel) {}
                    .accessibilityIdentifier("collection.blocked-outcome.cancel")
            } message: { decision in
                Text(decision.confirmationMessage(hasLaterIntent: currentReview?.context.hasLaterIntent == true))
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle, .loading:
            ProgressView("Checking the cloud version")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("collection.blocked-outcome.loading")

        case let .ready(review):
            reviewContent(review, failure: nil, isResolving: false)

        case let .resolving(review, _):
            reviewContent(review, failure: nil, isResolving: true)

        case let .failed(failure, review?):
            reviewContent(review, failure: failure, isResolving: false)

        case let .failed(failure, nil):
            unavailableContent(failure)

        case .resolved:
            ContentUnavailableView(
                "Change resolved",
                systemImage: "checkmark.circle",
                description: Text("Your decision was saved and the pending review is complete.")
            )
            .accessibilityIdentifier("collection.blocked-outcome.resolved")
        }
    }

    private func reviewContent(
        _ review: CollectionBlockedOutcomeReview,
        failure: CollectionBlockedOutcomeReviewModel.Failure?,
        isResolving: Bool
    ) -> some View {
        List {
            Section {
                if let title = mangaTitle(in: review) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.textPrimary)
                } else {
                    Text("Manga #\(review.context.operation.mangaID)")
                        .font(.headline)
                        .foregroundStyle(.textPrimary)
                }

                Text("Compare both versions before choosing. Nothing changes until you confirm.")
                    .foregroundStyle(.textSecondary)
            }

            Section("On this device") {
                CollectionBlockedOutcomeVersionView(version: .state(review.context.deviceState))
            }

            Section("In the cloud") {
                CollectionBlockedOutcomeVersionView(version: remoteVersion(in: review))
            }

            if review.context.hasLaterIntent {
                Section {
                    Label(
                        "There are newer changes waiting on this device. They will be preserved.",
                        systemImage: "clock.arrow.circlepath"
                    )
                    .foregroundStyle(.textSecondary)
                }
                .accessibilityIdentifier("collection.blocked-outcome.later-intent")
            }

            if let failure {
                Section {
                    Label(failure.message, systemImage: failure.systemImage)
                        .foregroundStyle(.dangerInk)
                        .accessibilityIdentifier("collection.blocked-outcome.failure")

                    if failure.canRetry {
                        Button("Check again") {
                            request = .review(UUID())
                        }
                        .accessibilityIdentifier("collection.blocked-outcome.retry")
                    }
                }
            } else {
                Section {
                    if review.context.hasLaterIntent == false {
                        Button("Use cloud version", role: .destructive) {
                            proposedDecision = .useRemote
                        }
                        .disabled(isResolving)
                        .accessibilityIdentifier("collection.blocked-outcome.use-cloud")
                    }

                    Button(deviceActionTitle(for: review)) {
                        proposedDecision = .keepDevice
                    }
                    .disabled(isResolving)
                    .accessibilityIdentifier("collection.blocked-outcome.keep-device")
                } header: {
                    Text(actionSectionTitle(for: review))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .overlay {
            if isResolving {
                ProgressView("Saving your decision")
                    .padding()
                    .background(.surface, in: .rect(cornerRadius: 12))
                    .accessibilityIdentifier("collection.blocked-outcome.resolving")
            }
        }
    }

    private func unavailableContent(_ failure: CollectionBlockedOutcomeReviewModel.Failure) -> some View {
        ScrollView {
            ContentUnavailableView {
                Label(failure.title, systemImage: failure.systemImage)
            } description: {
                Text(failure.message)
            } actions: {
                if failure.canRetry {
                    Button("Check again") {
                        request = .review(UUID())
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("collection.blocked-outcome.retry")
                }
            }
            .padding(.vertical, 24)
        }
        .accessibilityIdentifier("collection.blocked-outcome.failure")
    }

    private var currentReview: CollectionBlockedOutcomeReview? {
        switch model.state {
        case let .ready(review), let .resolving(review, _), let .failed(_, review?):
            review
        case .idle, .loading, .failed(_, nil), .resolved:
            nil
        }
    }

    private func mangaTitle(in review: CollectionBlockedOutcomeReview) -> String? {
        if let title = review.context.mangaSnapshot?.title {
            return title
        }
        guard case let .present(_, mangaSnapshot) = review.evidence else { return nil }
        return mangaSnapshot.title
    }

    private func remoteVersion(
        in review: CollectionBlockedOutcomeReview
    ) -> CollectionBlockedOutcomeVersionView.Version {
        switch review.evidence {
        case .absent:
            .absent
        case let .present(state, _):
            .state(state)
        }
    }

    private func deviceActionTitle(for review: CollectionBlockedOutcomeReview) -> LocalizedStringResource {
        review.context.hasLaterIntent ? "Continue with this device’s changes" : "Send this device’s version"
    }

    private func actionSectionTitle(for review: CollectionBlockedOutcomeReview) -> LocalizedStringResource {
        review.context.hasLaterIntent ? "Continue with newer changes" : "Choose which version to use"
    }
}

private extension CollectionBlockedOutcomeDecision {
    var actionTitle: LocalizedStringResource {
        switch self {
        case .useRemote:
            "Use cloud version"
        case .keepDevice:
            "Continue"
        }
    }

    func confirmationMessage(hasLaterIntent: Bool) -> LocalizedStringResource {
        switch self {
        case .useRemote:
            "The version on this device will be replaced by the current cloud version. This cannot be undone."
        case .keepDevice where hasLaterIntent:
            "The newer changes on this device will be preserved and sending will continue."
        case .keepDevice:
            "The version on this device will be sent again and may replace the current cloud version."
        }
    }
}

private extension CollectionBlockedOutcomeReviewModel.Failure {
    var title: LocalizedStringResource {
        switch self {
        case .sessionChanged:
            "Review no longer available"
        case .operationUnavailable:
            "Change no longer pending"
        case .moreRecentChange:
            "Newer changes need review"
        case .incompatibleLocalState:
            "Device version cannot be reviewed"
        case .incompatibleRemoteState:
            "Cloud version cannot be compared"
        case .authorizationDenied:
            "Permission required"
        case .authenticationIncompatible:
            "Collection service unavailable"
        case .unavailable:
            "Cloud version unavailable"
        case .sequenceExhausted:
            "Change cannot be queued"
        case .persistenceConflict:
            "Decision not saved"
        case .remoteChanged:
            "Cloud version changed"
        }
    }

    var message: LocalizedStringResource {
        switch self {
        case .sessionChanged:
            """
            The active account changed while this review was open. Return to Account and open the current review again.
            """
        case .operationUnavailable:
            "This pending change was resolved or replaced before it could be reviewed."
        case .moreRecentChange:
            "This device has a newer pending change. Check again before continuing with that version."
        case .incompatibleLocalState:
            "The saved device data cannot be changed safely. Nothing in your collection was modified."
        case .incompatibleRemoteState:
            "The service returned Collection data that this version of the app cannot use safely. Nothing was modified."
        case .authorizationDenied:
            "Your active account cannot read this cloud version. Your session and pending change remain available."
        case .authenticationIncompatible:
            """
            The Collection service did not accept the active session. Your session and pending change remain available.
            """
        case .unavailable:
            "The cloud version could not be checked. Your pending change remains available for review."
        case .sequenceExhausted:
            "A safe follow-up change cannot be created. Your pending change remains unchanged."
        case .persistenceConflict:
            "Your decision could not be saved. The pending change is still available for review."
        case .remoteChanged:
            "The cloud version changed while you were deciding. Check it again before choosing."
        }
    }

    var systemImage: String {
        switch self {
        case .sessionChanged, .operationUnavailable:
            "arrow.trianglehead.2.clockwise.rotate.90"
        case .moreRecentChange, .remoteChanged:
            "arrow.triangle.2.circlepath"
        case .incompatibleLocalState, .incompatibleRemoteState, .sequenceExhausted:
            "exclamationmark.triangle"
        case .authorizationDenied:
            "lock"
        case .authenticationIncompatible, .unavailable:
            "icloud.slash"
        case .persistenceConflict:
            "externaldrive.badge.exclamationmark"
        }
    }
}

#Preview(
    "Blocked change with cloud version",
    traits: .modifier(CollectionBlockedOutcomePreviewModifier<CollectionBlockedOutcomePreviewScenarios.Empty>())
) {
    NavigationStack {
        CollectionBlockedOutcomeReviewView(
            operationID: CollectionBlockedOutcomePreviewFixtures.operationID,
            authority: CollectionBlockedOutcomePreviewFixtures.authority,
            resolution: .disabled,
            initialState: .ready(CollectionBlockedOutcomePreviewFixtures.presentReview)
        )
    }
}

#Preview(
    "Blocked deletion with cloud absence",
    traits: .modifier(CollectionBlockedOutcomePreviewModifier<CollectionBlockedOutcomePreviewScenarios.Empty>())
) {
    NavigationStack {
        CollectionBlockedOutcomeReviewView(
            operationID: CollectionBlockedOutcomePreviewFixtures.deletionOperationID,
            authority: CollectionBlockedOutcomePreviewFixtures.authority,
            resolution: .disabled,
            initialState: .ready(CollectionBlockedOutcomePreviewFixtures.absentReview)
        )
    }
}

#Preview(
    "Blocked change loading",
    traits: .modifier(CollectionBlockedOutcomePreviewModifier<CollectionBlockedOutcomePreviewScenarios.Empty>())
) {
    NavigationStack {
        CollectionBlockedOutcomeReviewView(
            operationID: CollectionBlockedOutcomePreviewFixtures.operationID,
            authority: CollectionBlockedOutcomePreviewFixtures.authority,
            resolution: .disabled,
            initialState: .loading
        )
    }
}

#Preview(
    "Blocked change unavailable",
    traits: .modifier(CollectionBlockedOutcomePreviewModifier<CollectionBlockedOutcomePreviewScenarios.Empty>())
) {
    NavigationStack {
        CollectionBlockedOutcomeReviewView(
            operationID: CollectionBlockedOutcomePreviewFixtures.operationID,
            authority: CollectionBlockedOutcomePreviewFixtures.authority,
            resolution: .disabled,
            initialState: .failed(.unavailable, review: nil)
        )
    }
}

#Preview(
    "Blocked change incompatible",
    traits: .modifier(CollectionBlockedOutcomePreviewModifier<CollectionBlockedOutcomePreviewScenarios.Empty>())
) {
    NavigationStack {
        CollectionBlockedOutcomeReviewView(
            operationID: CollectionBlockedOutcomePreviewFixtures.operationID,
            authority: CollectionBlockedOutcomePreviewFixtures.authority,
            resolution: .disabled,
            initialState: .failed(.incompatibleRemoteState, review: nil)
        )
    }
}

#Preview(
    "Blocked change with a newer intent",
    traits: .modifier(CollectionBlockedOutcomePreviewModifier<CollectionBlockedOutcomePreviewScenarios.Empty>())
) {
    NavigationStack {
        CollectionBlockedOutcomeReviewView(
            operationID: CollectionBlockedOutcomePreviewFixtures.operationID,
            authority: CollectionBlockedOutcomePreviewFixtures.authority,
            resolution: .disabled,
            initialState: .ready(CollectionBlockedOutcomePreviewFixtures.laterIntentReview)
        )
    }
}
