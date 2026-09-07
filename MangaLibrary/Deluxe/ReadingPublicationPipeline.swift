import Foundation

/// A failed session reconciliation must reach the owner of the structured consumer.
struct ReadingPublicationSessionReconciliationError: Error {
    let authority: SessionAuthority
    let underlyingError: any Error
}

/// Consumes committed intents through persisted projection, optional covers and the sole publisher.
///
/// The caller owns `run()` as a structured child task. Stopping a consumer leaves the latest
/// intent available for a later lifetime. A failed publication does not roll back Collection;
/// the next event can retry the current persisted state. Rejected session capabilities are reconciled
/// with their exact session owner before further consumption. A failed reconciliation terminates
/// `run()` so its caller can surface and retry the retirement. No lifecycle or live transport starts here.
actor ReadingPublicationPipeline {
    private let events: ReadingPublicationEvents
    private let mutations: CollectionMutationActor
    private let publisher: ReadingSnapshotPublisher
    private let loadCover: @Sendable (URL) async throws -> Data?
    private let reconcileSession: @Sendable (SessionAuthority) async throws -> Void

    init(
        events: ReadingPublicationEvents,
        mutations: CollectionMutationActor,
        publisher: ReadingSnapshotPublisher,
        loadCover: @escaping @Sendable (URL) async throws -> Data?,
        reconcileSession: @escaping @Sendable (SessionAuthority) async throws -> Void
    ) {
        self.events = events
        self.mutations = mutations
        self.publisher = publisher
        self.loadCover = loadCover
        self.reconcileSession = reconcileSession
    }

    func run() async throws {
        try Task.checkCancellation()
        let subscription = try events.subscribe()
        defer { events.release(subscription) }
        for await event in subscription.stream {
            try Task.checkCancellation()
            do {
                _ = try await process(event)
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as ReadingPublicationSessionReconciliationError {
                throw error
            } catch {
                try Task.checkCancellation()
            }
        }
        try Task.checkCancellation()
    }

    /// Rejects obsolete work and reconciles an unusable session before returning its original error.
    ///
    /// A reconciliation failure is wrapped so the structured consumer cannot silently continue while
    /// the session owner still owes durable retirement. Cancellation still reconciles an expired
    /// capability before propagating; it never requires a current publication ticket. Collection
    /// is never rolled back here.
    func process(_ event: ReadingPublicationEvent) async throws -> ReadingSnapshot? {
        do {
            return try await prepare(event)
        } catch let error as SessionCommitAuthorizationError {
            try await reconcile(authority: event.authorization.authority)
            throw error
        } catch CollectionReadingProjectionError.authenticationRequired {
            try await reconcile(authority: event.authorization.authority)
            throw CollectionReadingProjectionError.authenticationRequired
        } catch is CancellationError {
            do {
                try event.authorization.perform {}
            } catch is SessionCommitAuthorizationError {
                try await reconcile(authority: event.authorization.authority)
            }
            throw CancellationError()
        }
    }

    private func prepare(_ event: ReadingPublicationEvent) async throws -> ReadingSnapshot? {
        try Task.checkCancellation()
        try Self.validate(event)
        let projection: CollectionReadingProjection
        do {
            projection = try await mutations.readingProjection(authorization: event.authorization)
        } catch CollectionReadingProjectionError.cancelled {
            throw CancellationError()
        }
        try Task.checkCancellation()
        try Self.validate(event)
        let preferred = try await publisher.preferredStartMangaID(
            for: projection,
            requested: event.preferredStartMangaID,
            authorization: event.authorization,
            ticket: event.ticket
        )
        let loadCover = loadCover
        let collectionPreferred = try await publisher.preferredCollectionStartMangaID(
            for: projection,
            requested: event.preferredCollectionStartMangaID,
            authorization: event.authorization,
            ticket: event.ticket
        )
        let covers = try await ReadingCoverBatch.prepare(
            projection: projection,
            preferredStartMangaID: preferred,
            preferredCollectionStartMangaID: collectionPreferred
        ) { url in
            try Task.checkCancellation()
            try Self.validate(event)
            let source = try await loadCover(url)
            try Task.checkCancellation()
            try Self.validate(event)
            return source
        }
        try Task.checkCancellation()
        try Self.validate(event)
        let result = try await publisher.publish(
            projection: projection,
            preparedCovers: covers,
            authorization: event.authorization,
            ticket: event.ticket,
            preferredStartMangaID: preferred,
            preferredCollectionStartMangaID: collectionPreferred
        )
        events.consumePreference(for: event)
        return result
    }

    private func reconcile(authority: SessionAuthority) async throws {
        do {
            try await reconcileSession(authority)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw ReadingPublicationSessionReconciliationError(authority: authority, underlyingError: error)
        }
    }

    private static func validate(_ event: ReadingPublicationEvent) throws {
        try event.authorization.perform {
            try event.ticket.validate(authority: event.authorization.authority)
        }
    }
}
