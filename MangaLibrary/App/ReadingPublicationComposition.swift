import Foundation
import SwiftData

/// Shares one event source between the Collection writer and its structured publication consumer.
struct ReadingPublicationComposition {
    let mutations: CollectionMutationActor
    let publisher: ReadingSnapshotPublisher
    let events: ReadingPublicationEvents
    fileprivate let loadCover: @Sendable (URL) async throws -> Data?

    /// Binds authorization rejection to the same owner that closes the shared session fence.
    func makePipeline(sessionController: SessionController) -> ReadingPublicationPipeline {
        ReadingPublicationPipeline(
            events: events,
            mutations: mutations,
            publisher: publisher,
            loadCover: loadCover,
            reconcileSession: { authority in
                try await sessionController.reconcileReadingAuthorization(for: authority)
            }
        )
    }
}

extension AppComposition {
    /// Composes an isolated bridge with caller-owned storage, time, cover loading and reload delivery.
    ///
    /// The caller must inject these same events and publisher into its session owner. Construction
    /// starts no task or transport. Live App Group resolution and app lifecycle belong to DX4.
    static func makeReadingPublication(
        modelContainer: ModelContainer,
        sharedDirectory: URL,
        publisherDirectory: URL,
        now: @escaping @Sendable () -> Date,
        makeGeneration: @escaping @Sendable () -> UUID,
        loadCover: @escaping @Sendable (URL) async throws -> Data?,
        requestReload: @escaping @Sendable (Data) throws -> Void
    ) throws -> ReadingPublicationComposition {
        let events = ReadingPublicationEvents()
        let mutations = CollectionMutationActor(modelContainer: modelContainer, readingEvents: events)
        let storage = try ReadingSnapshotStorage(sharedDirectory: sharedDirectory, publisherDirectory: publisherDirectory)
        let covers = try ReadingCoverStorage(sharedDirectory: sharedDirectory, publisherDirectory: publisherDirectory)
        let publisher = ReadingSnapshotPublisher(
            storage: storage,
            now: now,
            makeGeneration: makeGeneration,
            requestReload: requestReload,
            coverStorage: covers
        )
        return ReadingPublicationComposition(
            mutations: mutations,
            publisher: publisher,
            events: events,
            loadCover: loadCover
        )
    }
}
