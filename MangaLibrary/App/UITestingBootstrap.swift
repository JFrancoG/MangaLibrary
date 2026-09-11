#if DEBUG
import Foundation
import SwiftData

struct UITestingBootstrap {
    let modelContainer: ModelContainer
    let collectionMutation: CollectionMutation
    let collectionSynchronization: CollectionSynchronization
    let collectionBlockedOutcomeResolution: CollectionBlockedOutcomeResolution
    let loadCatalogPage: CatalogModel.PageLoader
    let loadCatalogFilterOptions: CatalogModel.FilterOptionsLoader
    let accountModel: AccountModel
    let readingPublication: ReadingPublicationLifecycle?
    let presentsCollectionDetailProjection: Bool
    let presentsMountedCollectionDetail: Bool
    let collectionDetailUpdate: CollectionSynchronization

    @MainActor
    static func makeIfRequested(processArguments: [String]) throws -> Self? {
        let testsWatchConnectivity = processArguments.contains("-ui-testing-watch-connectivity")
        let testsEmptyReadings = processArguments.contains("-ui-testing-reading-empty")
        if testsWatchConnectivity || testsEmptyReadings {
            precondition(
                processArguments.contains("-ui-testing") && processArguments.contains("-ui-testing-reading-widget"),
                "Reading characterization requires the explicit synthetic fixture flags."
            )
#if !targetEnvironment(simulator)
            preconditionFailure("Native watch characterization is restricted to Simulator test installations.")
#endif
        }
        guard processArguments.contains("-ui-testing") else { return nil }

        // Automated runs own deterministic scenarios. Native watch transport requires an
        // additional Simulator-only characterization flag that no automated test plan supplies.
        let testsCollectionDetailProjection = processArguments.contains("-ui-testing-collection-detail-projection")
        let testsMountedCollectionDetail = processArguments.contains("-ui-testing-mounted-collection-detail")
        let testsBlockedOutcomeResolution = processArguments.contains("-ui-testing-blocked-outcome-resolution")
        let testsPendingLogout = processArguments.contains("-ui-testing-pending-logout")
        let testsReadingWidget = processArguments.contains("-ui-testing-reading-widget")
        let disablesCollectionSynchronization =
            testsCollectionDetailProjection
            || testsMountedCollectionDetail
            || testsBlockedOutcomeResolution
            || testsPendingLogout
            || testsReadingWidget
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        if testsMountedCollectionDetail {
            try UITestingCollectionScenarios.seedUITestingMountedCollectionDetail(in: container)
        }
        if testsBlockedOutcomeResolution {
            try UITestingCollectionScenarios.seedUITestingBlockedOutcomes(in: container)
        }
        if testsPendingLogout {
            try UITestingCollectionScenarios.seedUITestingPendingLogout(in: container)
        }
        let watchConnectivity = testsWatchConnectivity ? WatchReadingConnectivity() : nil
        let readingFixture = testsReadingWidget ? try UITestingReadingWidget(
            modelContainer: container,
            watchConnectivity: watchConnectivity,
            startsWithEmptyReadings: testsEmptyReadings
        ) : nil
        let mutationActor = readingFixture?.mutations ?? CollectionMutationActor(modelContainer: container)
        let account: AccountModel
        if let readingFixture {
            account = AccountModel(
                initialState: .authenticated(readingFixture.account, notice: nil),
                operations: readingFixture.operations()
            )
        } else if testsPendingLogout {
            let session = UITestingPendingLogoutSession(mutationActor: mutationActor)
            account = AccountModel(
                initialState: .authenticated(AccountPreviewSupport.account, notice: nil),
                operations: session.operations()
            )
        } else {
            let accountState: AccountModel.State = testsMountedCollectionDetail || testsBlockedOutcomeResolution
                ? .authenticated(AccountPreviewSupport.account, notice: nil)
                : .signedOut(failure: nil)
            account = AccountPreviewSupport.model(state: accountState)
        }
        let mutation = CollectionMutation(
            actor: mutationActor,
            accountModel: account,
            sessionAuthorization: readingFixture?.sessionAuthorization ?? .deterministic
        )
        let synchronization: CollectionSynchronization
        if processArguments.contains("-ui-testing-collection-authorization-denied") {
            synchronization = UITestingCollectionScenarios.uiTestingCollectionAuthorizationFailure()
        } else if disablesCollectionSynchronization {
            synchronization = .disabled
        } else {
            synchronization = UITestingCollectionScenarios.uiTestingCollectionSynchronization(actor: mutationActor)
        }
        let blockedOutcomeResolution = testsBlockedOutcomeResolution
            ? UITestingCollectionScenarios.uiTestingBlockedOutcomeResolution(actor: mutationActor)
            : .disabled
        let detailUpdate = testsMountedCollectionDetail
            ? UITestingCollectionScenarios.uiTestingCollectionDetailUpdate(actor: mutationActor)
            : .disabled

        return Self(
            modelContainer: container,
            collectionMutation: mutation,
            collectionSynchronization: synchronization,
            collectionBlockedOutcomeResolution: blockedOutcomeResolution,
            loadCatalogPage: CatalogPreviewSupport.pageLoader,
            loadCatalogFilterOptions: CatalogPreviewSupport.filterOptionsLoader,
            accountModel: account,
            readingPublication: readingFixture.map { fixture in
                ReadingPublicationLifecycle(runPipeline: {
                    try await fixture.run()
                })
            },
            presentsCollectionDetailProjection: testsCollectionDetailProjection,
            presentsMountedCollectionDetail: testsMountedCollectionDetail,
            collectionDetailUpdate: detailUpdate
        )
    }
}
#endif
