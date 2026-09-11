#if DEBUG
import Foundation
import SwiftData
import WidgetKit

/// Owns synthetic account data for an explicitly launched App Group integration scenario.
///
/// The root supplies an in-memory container and enables this owner only for both UI-testing flags.
/// This fixture takes over the canonical bridge and its existing private ledger in a test installation;
/// it never creates a second publisher ledger, accesses Keychain or performs network requests.
/// A separately enabled Simulator scenario activates native watch delivery only after retiring the
/// preceding bridge and seeding this launch's synthetic account, whose session generation is fresh.
/// Launch with `-ui-testing -ui-testing-reading-widget -ui-testing-watch-connectivity` for content;
/// add `-ui-testing-reading-empty` for an empty reading projection. Account logout exercises the
/// same canonical retirement; confirm discarding the synthetic pending changes when requested.
actor UITestingReadingWidget {
    nonisolated let mutations: CollectionMutationActor
    nonisolated let account: SessionAccount

    private let composition: ReadingPublicationComposition
    private let gate: SessionCommitGate
    private let watchConnectivity: WatchReadingConnectivity?
    private let startsWithEmptyReadings: Bool
    private var snapshot: SessionSnapshot
    private var prepared = false
    private var seededCount = 0
    private var loggingOut = false
    private var closeAttempted = false

    nonisolated var sessionAuthorization: CollectionSessionAuthorization {
        CollectionSessionAuthorization { [self] authority in
            await authorization(for: authority)
        }
    }

    init(
        modelContainer: ModelContainer,
        publicationClock: @escaping @Sendable () -> Date = Date.init,
        watchConnectivity: WatchReadingConnectivity? = nil,
        startsWithEmptyReadings: Bool = false
    ) throws {
        guard let sharedDirectory = ReadingWidgetBridge.sharedDirectory() else {
            throw SessionControllerError.persistenceUnavailable
        }
        let reading = try AppComposition.makeReadingPublication(
            modelContainer: modelContainer,
            sharedDirectory: sharedDirectory,
            publisherDirectory: AppComposition.readingPublisherDirectory,
            now: publicationClock,
            makeGeneration: { UUID() },
            loadCover: { _ in nil },
            requestReload: { _ in
                WidgetCenter.shared.reloadTimelines(ofKind: ReadingWidgetBridge.kind)
            },
            sendWatchContext: { data in
                try watchConnectivity?.send(data)
            }
        )
        let previewAccount = AccountPreviewSupport.account
        let account = SessionAccount(
            authority: SessionAuthority(
                userID: previewAccount.id,
                generation: watchConnectivity == nil ? previewAccount.authority.generation : UUID()
            ),
            id: previewAccount.id,
            email: previewAccount.email,
            isActive: previewAccount.isActive,
            isAdmin: previewAccount.isAdmin,
            role: previewAccount.role
        )
        composition = reading
        mutations = reading.mutations
        self.account = account
        self.watchConnectivity = watchConnectivity
        self.startsWithEmptyReadings = startsWithEmptyReadings
        snapshot = .active(account)
        gate = SessionCommitGate(
            activeAuthority: account.authority,
            now: { Date(timeIntervalSince1970: 1_800_000_000) }
        )
    }

    nonisolated func operations() -> AccountModel.Operations {
        AccountModel.Operations(
            currentSnapshot: { [self] in
                await currentSnapshot()
            },
            restore: { [self] in
                await currentSnapshot()
            },
            login: { _, _ in
                throw SessionControllerError.unavailable
            },
            register: { _, _ in .notSubmitted(.unavailable) },
            logout: { [self] discardPendingChanges in
                try await logout(discardPendingChanges: discardPendingChanges)
            }
        )
    }

    /// Seeds through the authorized writer once, then consumes changes within the caller's lifetime.
    /// A completed logout permanently prevents this fixture from publishing again during this launch.
    func run() async throws {
        try Task.checkCancellation()
        guard allowsPublication else { return }
        if !prepared {
            _ = try await composition.publisher.recover()
            guard allowsPublication else { return }
            if let retirement = try await composition.publisher.confirmNoSessionAfterRecovery() {
                try await composition.publisher.finishRetirement(retirement)
            }
            prepared = true
        }
        while seededCount < Self.readings.count {
            try Task.checkCancellation()
            guard allowsPublication else { return }
            let reading = Self.readings[seededCount]
            let command = Self.command(
                for: reading,
                authority: account.authority,
                emptyReading: startsWithEmptyReadings
            )
            do {
                _ = try await mutations.apply(
                    command,
                    authorization: gate.authorization(for: command.authority),
                    newOperationID: Self.operationID(for: UInt8(seededCount))
                )
            } catch CollectionMutationError.cancelled {
                throw CancellationError()
            } catch {
                guard allowsPublication else { return }
                throw error
            }
            seededCount += 1
        }
        guard allowsPublication else { return }
        let pipeline = ReadingPublicationPipeline(
            events: composition.events,
            mutations: mutations,
            publisher: composition.publisher,
            loadCover: composition.loadCover,
            reconcileSession: { [self] authority in
                try await reconcile(authority)
            },
            onProjectionUnchanged: { [self] _ in
                try? await deliverWatchContext()
            }
        )
        guard let watchConnectivity else {
            try await pipeline.run()
            return
        }
        // The fresh adapter has not been activated during recovery, so its send boundary cannot
        // transfer a preceding installation's pending publication before the verified retirement.
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { [self] in
                try await watchConnectivity.run { event in
                    if case .activated = event {
                        try? await deliverWatchContext()
                    }
                }
            }
            defer { group.cancelAll() }
            try await pipeline.run()
        }
    }

    private var allowsPublication: Bool {
        snapshot == .active(account)
            && !loggingOut
            && gate.authorizes(account.authority)
    }

    private func deliverWatchContext() async throws {
        guard prepared, let watchConnectivity else { return }
        try await composition.publisher.deliverWatchContext(
            authorization: authorization(for: account.authority),
            send: watchConnectivity.send
        )
    }

    private func currentSnapshot() -> SessionSnapshot { snapshot }

    private func authorization(for authority: SessionAuthority) -> SessionCommitAuthorization? {
        guard allowsPublication, authority == account.authority else { return nil }
        return gate.authorization(for: authority)
    }

    private func reconcile(_ authority: SessionAuthority) throws {
        guard authority == account.authority, !loggingOut else { return }
        if case .active = snapshot {
            try gate.authorization(for: authority).perform {}
        }
    }

    private func logout(discardPendingChanges: Bool) async throws -> SessionSnapshot {
        guard case .active = snapshot else { throw SessionControllerError.notAuthenticated }
        guard !loggingOut else { throw SessionControllerError.transitionInProgress }
        let authority = account.authority
        guard let authorization = gate.suspendForLogout(authority) else { throw SessionControllerError.sessionChanged }
        loggingOut = true
        defer { loggingOut = false }
        do {
            if !discardPendingChanges, try await mutations.hasPendingChangesForLogout(authorization: authorization) {
                throw SessionControllerError.pendingCollectionChanges
            }
            if discardPendingChanges {
                try await mutations.discardPendingChangesForLogout(authorization: authorization)
            }
            try authorization.perform {
                composition.events.invalidate(authority: authority)
            }
            closeAttempted = true
            let retirement = try await composition.publisher.close(authorization: authorization)
            gate.invalidate(authority)
            snapshot = .signedOut
            try await composition.publisher.finishRetirement(retirement)
            return snapshot
        } catch {
            if !closeAttempted {
                try reactivate(authority)
            }
            if let logoutError = error as? CollectionLogoutError, logoutError == .cancelled {
                throw CancellationError()
            }
            throw error
        }
    }

    private func reactivate(_ authority: SessionAuthority) throws {
        guard snapshot == .active(account), authority == account.authority else { return }
        gate.activate(authority)
        let resumed = gate.authorization(for: authority)
        _ = try resumed.perform {
            composition.events.record(authorization: resumed)
        }
    }
}

private extension UITestingReadingWidget {
    struct Reading {
        let mangaID: Int64
        let title: String
        let volume: Int64?
        let total: Int64?
        var ownedVolumes: [Int64] = []
        var isComplete = false
    }

    static let readings = [
        Reading(mangaID: 9_009, title: "Acuarela sin empezar", volume: nil, total: 12, ownedVolumes: [1, 3, 5]),
        Reading(mangaID: 9_010, title: "Archivo reservado", volume: nil, total: nil),
        Reading(mangaID: 9_001, title: "Alba de papel", volume: 3, total: 3, isComplete: true),
        Reading(mangaID: 9_002, title: "Bosque de tinta", volume: 2, total: 12, ownedVolumes: [1, 2, 4]),
        Reading(mangaID: 9_003, title: "Cuaderno de viajes", volume: 8, total: nil, ownedVolumes: [1, 8]),
        Reading(mangaID: 9_004, title: "Diario de una biblioteca", volume: 1, total: 5),
        Reading(mangaID: 9_005, title: "El jardín de las nubes", volume: 5, total: 9),
        Reading(mangaID: 9_006, title: "Faro de invierno", volume: 7, total: 10),
        Reading(mangaID: 9_007, title: "Gotas de tinta", volume: 4, total: 6),
        Reading(mangaID: 9_008, title: "Historias del viento", volume: 2, total: 8)
    ]

    static func command(
        for reading: Reading,
        authority: SessionAuthority,
        emptyReading: Bool
    ) -> CollectionMutationCommand {
        let manga = CollectionMangaSnapshot(
            mangaID: reading.mangaID,
            title: reading.title,
            titleEnglish: nil,
            titleJapanese: nil,
            synopsis: nil,
            score: 0,
            status: .publishing,
            authors: [],
            demographics: [],
            genres: [],
            themes: [],
            coverURL: nil
        )
        return CollectionMutationCommand(
            authority: authority,
            mangaID: reading.mangaID,
            mangaSnapshot: manga,
            knownTotalVolumes: reading.total,
            change: .replaceState(
                ownedVolumes: reading.ownedVolumes,
                readingVolume: emptyReading ? nil : reading.volume,
                isComplete: reading.isComplete
            )
        )
    }

    static func operationID(for index: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 64, 0, 128, 0, 0, 0, 0, 0, 84, index))
    }
}
#endif
