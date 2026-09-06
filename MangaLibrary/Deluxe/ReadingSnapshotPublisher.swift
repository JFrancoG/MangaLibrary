import CryptoKit
import Foundation

enum ReadingPublicationError: Error {
    case incompatibleState
    case fenceVerificationFailed
    case retirementInProgress
    case invalidGeneration
    case contextTooLarge
    case projectionAuthorityMismatch
    case staleProjection
}

/// Owns durable publication ordering. Only a session capability can publish content.
actor ReadingSnapshotPublisher {
    enum Recovery: Equatable {
        case ready
        case retirementPending(UUID)
        case retirementRequired
    }

    struct RetirementCommit: Equatable {
        let sessionGeneration: UUID
        let fence: SessionFence
    }

    private let storage: ReadingSnapshotStorage
    private let now: @Sendable () -> Date
    private let makeGeneration: @Sendable () -> UUID
    private let requestReload: @Sendable (Data) throws -> Void
    private let coverStorage: ReadingCoverStorage?

    init(
        storage: ReadingSnapshotStorage,
        now: @escaping @Sendable () -> Date,
        makeGeneration: @escaping @Sendable () -> UUID,
        requestReload: @escaping @Sendable (Data) throws -> Void,
        coverStorage: ReadingCoverStorage? = nil
    ) {
        self.storage = storage
        self.now = now
        self.makeGeneration = makeGeneration
        self.requestReload = requestReload
        self.coverStorage = coverStorage
    }

    /// Reconciles write intentions with canonical files, without reopening any session.
    ///
    /// A closed fence whose recovery metadata is lost cannot prove a harmless bootstrap.
    /// Its caller must retire any residual Keychain generation before accepting authentication.
    func recover() throws -> Recovery {
        let recovery = try recover(deliverReloads: true)
        recoverCovers()
        return recovery
    }

    private func recover(deliverReloads: Bool) throws -> Recovery {
        let stateBytes = try readCompatibleFile(.publisherState)
        let fenceBytes = try readCompatibleFile(.fence)
        let snapshotBytes = try readCompatibleFile(.snapshot)
        let fence = decodedFence(fenceBytes)
        var state: ReadingPublisherState
        if let decoded = decodedState(stateBytes) {
            state = decoded
        } else {
            let hasHistory = stateBytes != nil || fenceBytes != nil || snapshotBytes != nil
            let uncertain = hasHistory && fence?.allowedSessionGeneration == nil
            state = try rotateEpoch(after: fence?.publicationGeneration, requiresRetirement: uncertain)
        }

        if case let .bootstrap(target) = state.intent {
            if try currentFence() != target {
                try replaceAndVerifyFence(target)
            }
            state.intent = nil
            try save(state)
        }

        let current = try currentFence()
        if
            case let .retirement(retirement) = state.intent,
            current != retirement.fence,
            current == retirement.previousFence,
            var previous = retirement.previousState
        {
            if previous.publicationGeneration == state.publicationGeneration {
                previous.lastReservedRevision = max(previous.lastReservedRevision, state.lastReservedRevision)
                previous.lastReservedFenceRevision = max(
                    previous.lastReservedFenceRevision,
                    state.lastReservedFenceRevision
                )
            }
            try save(previous)
            return try recover(deliverReloads: deliverReloads)
        }
        guard
            let current,
            current.publicationGeneration == state.publicationGeneration,
            current.fenceRevision <= state.lastReservedFenceRevision
        else {
            let replacement = try rotateEpoch(after: state.publicationGeneration, requiresRetirement: true)
            return replacement.requiresRetirement ? .retirementRequired : .ready
        }

        if
            let snapshot = decodedSnapshot(snapshotBytes),
            snapshot.publicationGeneration == state.publicationGeneration,
            snapshot.revision > state.lastReservedRevision
        {
            let replacement = try rotateEpoch(
                after: state.publicationGeneration,
                requiresRetirement: current.allowedSessionGeneration == nil
            )
            return replacement.requiresRetirement ? .retirementRequired : .ready
        }

        if case let .retirement(retirement) = state.intent {
            if current == retirement.fence {
                return .retirementPending(retirement.sessionGeneration)
            }
            // The reserved close never replaced its target fence. Its counters remain consumed.
            state.intent = nil
            try save(state)
        } else if case let .publication(publication) = state.intent, deliverReloads {
            if let data = try readCompatibleFile(.snapshot), digest(data) == publication.snapshotDigest {
                let expected = publication.openingFence
                let sameSession = publication.isRedacted
                    ? current.allowedSessionGeneration == nil
                    : current.allowedSessionGeneration == publication.sessionGeneration
                let permitted = sameSession && (expected == nil || expected == current)
                if permitted {
                    do {
                        try requestReload(data)
                    } catch {
                        // Presentation is eventual; durable intent remains available for another opportunity.
                        return state.requiresRetirement ? .retirementRequired : .ready
                    }
                }
            }
            // Recovery never opens a fence. Incomplete activation needs a new session capability.
            state.intent = nil
            try save(state)
        }
        return state.requiresRetirement ? .retirementRequired : .ready
    }

    func pendingRetirement() throws -> RetirementCommit? {
        guard
            let state = decodedState(try readCompatibleFile(.publisherState)),
            case let .retirement(retirement) = state.intent,
            try currentFence() == retirement.fence
        else { return nil }
        return RetirementCommit(sessionGeneration: retirement.sessionGeneration, fence: retirement.fence)
    }

    /// The session owner calls this only after confirming that no Keychain authority remains.
    @discardableResult
    func confirmNoSessionAfterRecovery() throws -> RetirementCommit? {
        if let pending = try pendingRetirement() {
            return pending
        }
        guard let fence = try currentFence() else { throw ReadingPublicationError.fenceVerificationFailed }
        if let generation = fence.allowedSessionGeneration {
            return try close(sessionGeneration: generation)
        }
        var state = try requiredState()
        state.requiresRetirement = false
        try save(state)
        return nil
    }

    /// Budgets persisted candidates and already resolved cover references before any durable effect.
    ///
    /// The capability must belong to the projection's exact authority. Cover identifiers are planning
    /// inputs, not proof of file integrity; resource preparation and admission belong to the caller.
    /// This entry point does not establish ordering between two projections of the same session.
    func publish(
        projection: CollectionReadingProjection,
        coverResourceIDs: [Manga.ID: String] = [:],
        authorization: SessionCommitAuthorization
    ) throws -> ReadingSnapshot? {
        try Task.checkCancellation()
        guard projection.authority == authorization.authority else {
            throw ReadingPublicationError.projectionAuthorityMismatch
        }
        try authorization.perform {}
        let plan = try ReadingPublicationPlan(projection: projection, coverResourceIDs: coverResourceIDs)
        return try publish(items: plan.items, totalEligibleCount: plan.totalEligibleCount, authorization: authorization)
    }

    /// Admits only resources referenced by the final changed prefix, before replacing its manifest.
    ///
    /// The event pipeline supplies a ticket invalidated by every newer committed intent. Validation
    /// shares the session critical section with resource admission, manifest replacement and fence
    /// opening, so preparation order cannot overwrite a later Collection commit. A stale attempt
    /// may consume a reservation but cannot pass a subsequent publication boundary.
    func publish(
        projection: CollectionReadingProjection,
        preparedCovers: [Manga.ID: ReadingCoverResource],
        authorization: SessionCommitAuthorization,
        ticket: ReadingPublicationTicket? = nil
    ) throws -> ReadingSnapshot? {
        try Task.checkCancellation()
        guard projection.authority == authorization.authority else {
            throw ReadingPublicationError.projectionAuthorityMismatch
        }
        try withPublicationAuthorization(authorization, ticket: ticket) {}
        let upperBound = try ReadingPublicationPlan(projection: projection)
        let proposed = try ReadingPublicationPlan(
            projection: projection,
            coverResourceIDs: preparedCovers.mapValues(\.identifier)
        )
        let previous = try publicationPredecessor(authorization: authorization, ticket: ticket)
        if
            previous?.sessionGeneration == authorization.authority.generation,
            previous?.items == proposed.items,
            previous?.totalEligibleCount == proposed.totalEligibleCount
        {
            try withPublicationAuthorization(authorization, ticket: ticket) {}
            return nil
        }
        let candidates = upperBound.items.compactMap { preparedCovers[$0.mangaID] }
        let admissible: [ReadingCoverResource]
        do {
            admissible = try coverStorage?.admissibleResources(
                candidates,
                currentManifest: storage.read(.snapshot)
            ) ?? []
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // Optional images can fall back only while the candidate manifest is still uncommitted.
            try Task.checkCancellation()
            admissible = []
        }
        let identifiers = Set(admissible.map(\.identifier))
        let references = preparedCovers.compactMapValues { resource in
            identifiers.contains(resource.identifier) ? resource.identifier : nil
        }
        let plan = try ReadingPublicationPlan(projection: projection, coverResourceIDs: references)
        let selected = Set(plan.items.compactMap(\.coverResourceID))
        return try commit(
            items: plan.items,
            totalEligibleCount: plan.totalEligibleCount,
            resources: admissible.filter { selected.contains($0.identifier) },
            authorization: authorization,
            ticket: ticket
        )
    }

    /// Commits a prepared projection only while its exact session capability remains valid.
    ///
    /// An identical permitted projection returns `nil` without consuming a revision or requesting a reload.
    /// A pending reload remains available to explicit recovery, including session restoration. Failed
    /// writes consume their reservation; a reload failure preserves a retryable intention.
    /// The caller supplies the already ordered and budgeted prefix, never live SwiftData models.
    func publish(
        items: [ReadingSnapshot.Item],
        totalEligibleCount: Int64,
        authorization: SessionCommitAuthorization
    ) throws -> ReadingSnapshot? {
        try commit(
            items: items,
            totalEligibleCount: totalEligibleCount,
            resources: [],
            authorization: authorization
        )
    }

    private func commit(
        items: [ReadingSnapshot.Item],
        totalEligibleCount: Int64,
        resources: [ReadingCoverResource],
        authorization: SessionCommitAuthorization,
        ticket: ReadingPublicationTicket? = nil
    ) throws -> ReadingSnapshot? {
        let previous = try publicationPredecessor(authorization: authorization, ticket: ticket)
        let generation = authorization.authority.generation
        if
            previous?.sessionGeneration == generation,
            previous?.items == items,
            previous?.totalEligibleCount == totalEligibleCount
        {
            try withPublicationAuthorization(authorization, ticket: ticket) {}
            return nil
        }

        var state = try stateWithCapacity()
        let revision = state.lastReservedRevision + 1
        let snapshot = try ReadingSnapshot(
            publicationGeneration: state.publicationGeneration,
            revision: revision,
            sessionGeneration: generation,
            state: items.isEmpty ? .empty : .content,
            generatedAt: now(),
            totalEligibleCount: totalEligibleCount,
            items: items
        )
        let data = try ReadingSnapshotCodec.encode(snapshot)
        guard try ReadingSnapshotCodec.contextByteCount(for: data) <= 32_768 else {
            throw ReadingPublicationError.contextTooLarge
        }
        // A failed read is never evidence that the predecessor manifest was absent.
        let previousManifest = resources.isEmpty ? nil : try storage.read(.snapshot)

        let oldFence = try currentFence()
        var openingFence: SessionFence?
        if oldFence?.allowedSessionGeneration != generation {
            // Switching identities is always closed first, even without an exposed consumer yet.
            if oldFence?.allowedSessionGeneration != nil {
                state.lastReservedFenceRevision += 1
                let closed = try SessionFence(
                    publicationGeneration: state.publicationGeneration,
                    fenceRevision: state.lastReservedFenceRevision,
                    allowedSessionGeneration: nil
                )
                state.intent = .bootstrap(closed)
                try save(state)
                try withPublicationAuthorization(authorization, ticket: ticket) {
                    try replaceAndVerifyFence(closed)
                }
            }
            state.lastReservedFenceRevision += 1
            openingFence = try SessionFence(
                publicationGeneration: state.publicationGeneration,
                fenceRevision: state.lastReservedFenceRevision,
                allowedSessionGeneration: generation
            )
        }
        state.lastReservedRevision = revision
        state.intent = .publication(.init(
            revision: revision,
            sessionGeneration: generation,
            snapshotDigest: digest(data),
            openingFence: openingFence,
            isRedacted: false
        ))
        try save(state)
        try Task.checkCancellation()
        if !resources.isEmpty {
            try withPublicationAuthorization(authorization, ticket: ticket) {
                try coverStorage?.recover(currentManifest: previousManifest)
                try coverStorage?.prepare(
                    resources,
                    attemptID: makeGeneration(),
                    previousManifest: previousManifest,
                    expectedManifest: data
                )
            }
        } else {
            recoverCovers()
        }
        try Task.checkCancellation()
        try withPublicationAuthorization(authorization, ticket: ticket) {
            try storage.replace(.snapshot, data)
        }
        if let openingFence {
            try Task.checkCancellation()
            try withPublicationAuthorization(authorization, ticket: ticket) {
                try replaceAndVerifyFence(openingFence)
            }
        }
        recoverCovers()
        do {
            try requestReload(data)
        } catch {
            return snapshot
        }
        state.intent = nil
        try save(state)
        return snapshot
    }

    private func publicationPredecessor(
        authorization: SessionCommitAuthorization,
        ticket: ReadingPublicationTicket? = nil
    ) throws -> ReadingSnapshot? {
        try Task.checkCancellation()
        try withPublicationAuthorization(authorization, ticket: ticket) {}
        let generation = authorization.authority.generation
        switch try recover(deliverReloads: false) {
        case .ready:
            break
        case let .retirementPending(outgoing) where outgoing != generation:
            // A newly authorized Keychain generation proves that the outgoing one is no longer authority.
            var state = try requiredState()
            state.intent = nil
            state.requiresRetirement = false
            try withPublicationAuthorization(authorization, ticket: ticket) {
                try save(state)
            }
        case .retirementPending, .retirementRequired:
            throw ReadingPublicationError.retirementInProgress
        }
        do {
            return try ReadingSnapshotReader(storage: storage).read()
        } catch ReadingSnapshotStorageError.incompatibleFile {
            return nil
        }
    }

    /// Linearizes supersession checks with the Collection commits using this session gate.
    private func withPublicationAuthorization<Result>(
        _ authorization: SessionCommitAuthorization,
        ticket: ReadingPublicationTicket?,
        operation: () throws -> Result
    ) throws -> Result {
        try authorization.perform {
            try ticket?.validate(authority: authorization.authority)
            return try operation()
        }
    }

    private func recoverCovers() {
        guard let coverStorage else { return }
        do {
            try coverStorage.recover(currentManifest: storage.read(.snapshot))
        } catch {
            // Optional cover maintenance cannot delay session denial or roll back a committed manifest.
        }
    }

    /// Verifies durable denial before the session owner conditionally removes Keychain.
    ///
    /// Cancellation is observed only before the verified close. The returned commit authorizes
    /// eventual redaction, not content publication, and must never be used to reactivate a session.
    func close(authorization: SessionLogoutAuthorization) throws -> RetirementCommit {
        let generation = authorization.authority.generation
        if let replaced = try replacementCommit(for: generation) {
            return replaced
        }
        return try authorization.perform {
            try close(sessionGeneration: generation, allowsCancellation: true)
        }
    }

    func close(authorization: SessionInvalidationAuthorization) throws -> RetirementCommit {
        let generation = authorization.authority.generation
        if let replaced = try replacementCommit(for: generation) {
            return replaced
        }
        return try authorization.perform {
            try close(sessionGeneration: generation, allowsCancellation: false)
        }
    }

    /// Resumes only the session owner's captured retirement, which blocks replacement login until cleanup completes.
    /// This is not an entry point for delayed consumer events or publication authorization.
    func close(sessionGeneration: UUID) throws -> RetirementCommit {
        try close(sessionGeneration: sessionGeneration, allowsCancellation: false)
    }

    /// Completes eventual redaction only while the exact committed close remains canonical.
    ///
    /// The caller has already conditionally removed Keychain. Failure leaves a retryable intention;
    /// it must never reactivate the outgoing session or roll back the closed fence.
    func finishRetirement(_ commit: RetirementCommit) throws {
        guard
            commit.fence.allowedSessionGeneration == nil,
            let state = decodedState(try readCompatibleFile(.publisherState)),
            case let .retirement(retirement) = state.intent,
            retirement.sessionGeneration == commit.sessionGeneration,
            retirement.fence == commit.fence,
            try currentFence() == commit.fence
        else { return }

        let existingData = try readCompatibleFile(.snapshot)
        let existing = decodedSnapshot(existingData)
        let data: Data
        if
            existing?.publicationGeneration == state.publicationGeneration,
            existing?.revision == retirement.redactionRevision,
            existing?.sessionGeneration == retirement.redactionSessionGeneration,
            existing?.state == .redacted,
            let existingData
        {
            data = existingData
        } else {
            let snapshot = try ReadingSnapshot(
                publicationGeneration: state.publicationGeneration,
                revision: retirement.redactionRevision,
                sessionGeneration: retirement.redactionSessionGeneration,
                state: .redacted,
                generatedAt: now(),
                totalEligibleCount: nil,
                items: []
            )
            data = try ReadingSnapshotCodec.encode(snapshot)
            try storage.replace(.snapshot, data)
        }
        var completed = state
        completed.requiresRetirement = false
        completed.intent = .publication(.init(
            revision: retirement.redactionRevision,
            sessionGeneration: retirement.redactionSessionGeneration,
            snapshotDigest: digest(data),
            openingFence: commit.fence,
            isRedacted: true
        ))
        try save(completed)
        do {
            try requestReload(data)
        } catch {
            return
        }
        completed.intent = nil
        try save(completed)
    }

    private func close(sessionGeneration: UUID, allowsCancellation: Bool) throws -> RetirementCommit {
        let recovery = try recover(deliverReloads: false)
        if let pending = try pendingRetirement(), pending.sessionGeneration == sessionGeneration {
            return pending
        }
        if let fence = try currentFence(), let allowed = fence.allowedSessionGeneration, allowed != sessionGeneration {
            return RetirementCommit(sessionGeneration: sessionGeneration, fence: fence)
        }
        if allowsCancellation {
            try Task.checkCancellation()
        }
        var state = try requiredState()
        let previousState = state.withoutRetirementPredecessor()
        let previousFence = try currentFence()
        let redactionGeneration: UUID
        if case let .retirement(outgoing) = state.intent {
            redactionGeneration = outgoing.redactionSessionGeneration
        } else if let previous = decodedSnapshot(try readCompatibleFile(.snapshot))?.sessionGeneration {
            // Accepted reloads are still eventual: an unpublished replacement never becomes the cache recipient.
            redactionGeneration = previous
        } else if case let .publication(publication) = state.intent, publication.isRedacted {
            redactionGeneration = publication.sessionGeneration
        } else {
            redactionGeneration = sessionGeneration
        }
        if state.lastReservedRevision == .max || state.lastReservedFenceRevision == .max {
            let generation = makeGeneration()
            guard generation != state.publicationGeneration else { throw ReadingPublicationError.invalidGeneration }
            state = ReadingPublisherState(
                formatVersion: 1,
                publicationGeneration: generation,
                lastReservedRevision: 0,
                lastReservedFenceRevision: 0,
                requiresRetirement: state.requiresRetirement,
                intent: nil
            )
        }
        state.lastReservedRevision += 1
        state.lastReservedFenceRevision += 1
        let closed = try SessionFence(
            publicationGeneration: state.publicationGeneration,
            fenceRevision: state.lastReservedFenceRevision,
            allowedSessionGeneration: nil
        )
        state.requiresRetirement = recovery == .retirementRequired
        state.intent = .retirement(.init(
            sessionGeneration: sessionGeneration,
            redactionSessionGeneration: redactionGeneration,
            fence: closed,
            redactionRevision: state.lastReservedRevision,
            previousState: previousState,
            previousFence: previousFence
        ))
        try save(state)
        if allowsCancellation {
            try Task.checkCancellation()
        }
        try replaceAndVerifyFence(closed)
        // No fallible bookkeeping or cancellation check follows the verified point of no return.
        return RetirementCommit(sessionGeneration: sessionGeneration, fence: closed)
    }

    private func replacementCommit(for generation: UUID) throws -> RetirementCommit? {
        guard
            let fence = try currentFence(),
            let allowed = fence.allowedSessionGeneration,
            allowed != generation
        else { return nil }
        return RetirementCommit(sessionGeneration: generation, fence: fence)
    }

    private func stateWithCapacity() throws -> ReadingPublisherState {
        let state = try requiredState()
        if state.lastReservedRevision == .max || state.lastReservedFenceRevision >= UInt64.max - 1 {
            return try rotateEpoch(after: state.publicationGeneration, requiresRetirement: state.requiresRetirement)
        }
        return state
    }

    private func rotateEpoch(after previous: UUID?, requiresRetirement: Bool) throws -> ReadingPublisherState {
        let generation = makeGeneration()
        guard generation != previous else { throw ReadingPublicationError.invalidGeneration }
        let closed = try SessionFence(
            publicationGeneration: generation,
            fenceRevision: 1,
            allowedSessionGeneration: nil
        )
        var state = ReadingPublisherState(
            formatVersion: 1,
            publicationGeneration: generation,
            lastReservedRevision: 0,
            lastReservedFenceRevision: 1,
            requiresRetirement: requiresRetirement,
            intent: .bootstrap(closed)
        )
        try save(state)
        try replaceAndVerifyFence(closed)
        state.intent = nil
        try save(state)
        return state
    }

    private func requiredState() throws -> ReadingPublisherState {
        guard let state = decodedState(try readCompatibleFile(.publisherState)) else {
            throw ReadingPublicationError.incompatibleState
        }
        return state
    }

    private func currentFence() throws -> SessionFence? {
        decodedFence(try readCompatibleFile(.fence))
    }

    private func replaceAndVerifyFence(_ fence: SessionFence) throws {
        try storage.replace(.fence, ReadingSnapshotCodec.encodeFence(fence))
        guard try currentFence() == fence else { throw ReadingPublicationError.fenceVerificationFailed }
    }

    private func save(_ state: ReadingPublisherState) throws {
        try state.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        try storage.replace(.publisherState, encoder.encode(state))
    }

    private func readCompatibleFile(_ file: ReadingSnapshotStorage.File) throws -> Data? {
        do {
            return try storage.read(file)
        } catch ReadingSnapshotStorageError.incompatibleFile {
            // Preserve presence: an unreadable fence is not an absent first-install fence.
            return Data()
        }
    }

    private func decodedState(_ data: Data?) -> ReadingPublisherState? {
        guard let data else { return nil }
        do {
            let state = try JSONDecoder().decode(ReadingPublisherState.self, from: data)
            try state.validate()
            return state
        } catch {
            return nil
        }
    }

    private func decodedFence(_ data: Data?) -> SessionFence? {
        guard let data else { return nil }
        return try? ReadingSnapshotCodec.decodeFence(data)
    }

    private func decodedSnapshot(_ data: Data?) -> ReadingSnapshot? {
        guard let data else { return nil }
        return try? ReadingSnapshotCodec.decode(data)
    }

    private func digest(_ data: Data) -> Data { Data(SHA256.hash(data: data)) }
}
