//
//  SessionPersistenceFailureTests.swift
//  MangaLibraryTests
//

import Foundation
import Synchronization
import Testing
@testable import MangaLibrary

@Suite("Session persistence failure boundaries", .tags(.fast))
struct SessionPersistenceFailureTests {
    @Test("A failed ledger activation never publishes or retains its new bundle")
    func failedActivationRemovesTheOrphanBundle() async throws(any Error) {
        let storage = ControlledSessionPersistenceStorage()
        storage.failNext(.writeLedger, with: .fileSystemFailure)
        let persistence = SessionPersistenceActor(
            operations: storage.operations()
        )
        let bundle = try makeBundle(generation: Self.generationA)

        await #expect(throws: SessionStorageError.fileSystemFailure) {
            try await persistence.activate(
                userID: Self.userA,
                generation: Self.generationA,
                access: bundle.access,
                refresh: bundle.refresh
            )
        }

        let snapshot = storage.snapshot()
        #expect(snapshot.ledger == nil)
        #expect(snapshot.bundles.isEmpty)
        #expect(
            snapshot.journal == [
                .readLedger,
                .removeAllBundles,
                .writeBundle,
                .writeLedger,
                .removeBundle,
            ]
        )
    }

    @Test("An unavailable protected ledger defers restoration with zero mutation")
    func unavailableProtectedLedgerDoesNotTriggerCleanup() async throws(any Error) {
        let bundle = try makeBundle(generation: Self.generationA)
        let ledger = SessionLedgerRecord.active(
            userID: Self.userA,
            generation: Self.generationA,
            revision: 4
        )
        let storage = ControlledSessionPersistenceStorage(
            ledger: ledger,
            bundles: [Self.generationA: bundle]
        )
        storage.failNext(.readLedger, with: .temporarilyUnavailable)
        let persistence = SessionPersistenceActor(
            operations: storage.operations()
        )

        await #expect(throws: SessionStorageError.temporarilyUnavailable) {
            try await persistence.restore()
        }

        let snapshot = storage.snapshot()
        #expect(snapshot.ledger == ledger)
        #expect(snapshot.bundles == [Self.generationA: bundle])
        #expect(snapshot.journal == [.readLedger])
    }

    @Test("An unavailable protected bundle defers restoration with zero mutation")
    func unavailableProtectedBundleDoesNotTriggerCleanup() async throws(any Error) {
        let bundle = try makeBundle(generation: Self.generationA)
        let ledger = SessionLedgerRecord.active(
            userID: Self.userA,
            generation: Self.generationA,
            revision: 4
        )
        let storage = ControlledSessionPersistenceStorage(
            ledger: ledger,
            bundles: [Self.generationA: bundle]
        )
        storage.failNext(.readBundle, with: .temporarilyUnavailable)
        let persistence = SessionPersistenceActor(
            operations: storage.operations()
        )

        await #expect(throws: SessionStorageError.temporarilyUnavailable) {
            try await persistence.restore()
        }

        let snapshot = storage.snapshot()
        #expect(snapshot.ledger == ledger)
        #expect(snapshot.bundles == [Self.generationA: bundle])
        #expect(snapshot.journal == [.readLedger, .readBundle])
    }

    @Test("A corrupt protected bundle fails closed and preserves only its scope")
    func corruptProtectedBundleRequiresAuthentication() async throws(any Error) {
        let bundle = try makeBundle(generation: Self.generationA)
        let ledger = SessionLedgerRecord.active(
            userID: Self.userA,
            generation: Self.generationA,
            revision: 4
        )
        let storage = ControlledSessionPersistenceStorage(
            ledger: ledger,
            bundles: [Self.generationA: bundle]
        )
        storage.failNext(.readBundle, with: .corruptSecretBundle)
        let persistence = SessionPersistenceActor(
            operations: storage.operations()
        )

        #expect(
            try await persistence.restore()
                == .authenticationRequired(Self.userA)
        )

        let snapshot = storage.snapshot()
        #expect(
            snapshot.ledger
                == .authenticationRequired(userID: Self.userA, revision: 6)
        )
        #expect(snapshot.bundles.isEmpty)
        #expect(
            snapshot.journal == [
                .readLedger,
                .readBundle,
                .writeLedger,
                .removeBundle,
                .readLedger,
                .writeLedger,
            ]
        )
    }

    @Test("Logout reserves both revisions before its first durable mutation")
    func logoutRevisionCannotWrap() async throws(any Error) {
        let bundle = try makeBundle(generation: Self.generationA)
        let ledger = SessionLedgerRecord.active(
            userID: Self.userA,
            generation: Self.generationA,
            revision: UInt64.max - 1
        )
        let storage = ControlledSessionPersistenceStorage(
            ledger: ledger,
            bundles: [Self.generationA: bundle]
        )
        let persistence = SessionPersistenceActor(
            operations: storage.operations()
        )
        let authority = SessionAuthority(
            userID: Self.userA,
            generation: Self.generationA,
            revision: UInt64.max - 1
        )

        await #expect(throws: SessionPersistenceError.revisionExhausted) {
            try await persistence.prepareLogout(expected: authority)
        }

        let snapshot = storage.snapshot()
        #expect(snapshot.ledger == ledger)
        #expect(snapshot.bundles == [Self.generationA: bundle])
        #expect(snapshot.journal == [.readLedger])
    }

    @Test("A cleanup failure after invalidation never reopens the session")
    func recoveryResumesAfterThePointOfNoReturn() async throws(any Error) {
        let storage = ControlledSessionPersistenceStorage()
        let persistence = SessionPersistenceActor(
            operations: storage.operations()
        )
        let bundle = try makeBundle(generation: Self.generationA)
        let active = try await persistence.activate(
            userID: Self.userA,
            generation: Self.generationA,
            access: bundle.access,
            refresh: bundle.refresh
        )
        let prepared = try #require(
            try await persistence.prepareLogout(expected: active.authority)
        )
        storage.failNext(.removeBundle, with: .temporarilyUnavailable)

        await #expect(throws: SessionStorageError.temporarilyUnavailable) {
            try await persistence.completeLogout(expected: prepared)
        }

        let pending = try #require(storage.snapshot().ledger)
        #expect(pending.phase == .invalidatedCleanupPending)
        #expect(pending.cleanupCompletion == .signedOut)
        #expect(storage.snapshot().bundles[Self.generationA] == bundle)
        #expect(
            try await persistence.cancelLogout(expected: prepared) == nil
        )

        let relaunched = SessionPersistenceActor(
            operations: storage.operations()
        )
        #expect(try await relaunched.restore() == .signedOut)
        #expect(storage.snapshot().ledger == nil)
        #expect(storage.snapshot().bundles.isEmpty)
    }

    private func makeBundle(generation: UUID) throws(SessionStorageError) -> SessionSecretBundle {
        try SessionSecretBundle(
            generation: generation,
            access: SessionCredential(
                value: "synthetic-access",
                use: .access,
                expiresAt: Self.issuedAt.addingTimeInterval(3_600)
            ),
            refresh: SessionCredential(
                value: "synthetic-refresh",
                use: .refresh,
                expiresAt: Self.issuedAt.addingTimeInterval(2_592_000)
            )
        )
    }

    private static let issuedAt = Date(timeIntervalSince1970: 1_700_000_000)
    private static let userA = UUID(
        uuidString: "11111111-2222-3333-4444-555555555555"
    )!
    private static let generationA = UUID(
        uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
    )!
}

final class ControlledSessionPersistenceStorage: Sendable {
    enum Operation: Hashable, Sendable {
        case readLedger
        case writeLedger
        case removeLedger
        case readBundle
        case writeBundle
        case removeBundle
        case removeAllBundles
    }

    struct Snapshot: Sendable {
        let ledger: SessionLedgerRecord?
        let bundles: [UUID: SessionSecretBundle]
        let journal: [Operation]
    }

    private struct State: Sendable {
        var ledger: SessionLedgerRecord?
        var bundles: [UUID: SessionSecretBundle]
        var nextFailure: (Operation, SessionStorageError)?
        var operationGates: [Operation: [SessionStorageOperationGate]] = [:]
        var journal: [Operation] = []
    }

    private let state: Mutex<State>
    private let operationLock = Mutex<Void>(())

    init(ledger: SessionLedgerRecord? = nil, bundles: [UUID: SessionSecretBundle] = [:]) {
        state = Mutex(
            State(
                ledger: ledger,
                bundles: bundles,
                nextFailure: nil
            )
        )
    }

    func operations() -> SessionPersistenceActor.Operations {
        SessionPersistenceActor.Operations(
            readLedger: { [self] in
                try perform(.readLedger) { $0.ledger }
            },
            writeLedger: { [self] record in
                try perform(.writeLedger) { $0.ledger = record }
            },
            removeLedger: { [self] in
                try perform(.removeLedger) { $0.ledger = nil }
            },
            readBundle: { [self] generation in
                try perform(.readBundle) { $0.bundles[generation] }
            },
            writeBundle: { [self] bundle in
                try perform(.writeBundle) {
                    $0.bundles[bundle.generation] = bundle
                }
            },
            removeBundle: { [self] generation in
                try perform(.removeBundle) {
                    $0.bundles[generation] = nil
                }
            },
            removeAllBundles: { [self] in
                try perform(.removeAllBundles) { $0.bundles.removeAll() }
            }
        )
    }

    func failNext(_ operation: Operation, with error: SessionStorageError) {
        state.withLock {
            $0.nextFailure = (operation, error)
        }
    }

    func gateNext(_ operation: Operation) -> SessionStorageOperationGate {
        let gate = SessionStorageOperationGate()
        state.withLock {
            $0.operationGates[operation, default: []].append(gate)
        }
        return gate
    }

    func snapshot() -> Snapshot {
        state.withLock {
            Snapshot(
                ledger: $0.ledger,
                bundles: $0.bundles,
                journal: $0.journal
            )
        }
    }

    private func perform<Result>(
        _ operation: Operation,
        body: (inout State) -> Result
    ) throws(any Error) -> Result {
        try operationLock.withLock { _ in
            let (gate, failure) = state.withLock { state in
                state.journal.append(operation)
                let gate = state.operationGates[operation]?.removeFirst()
                if state.operationGates[operation]?.isEmpty == true {
                    state.operationGates[operation] = nil
                }

                let failure: SessionStorageError?
                if
                    let planned = state.nextFailure,
                    planned.0 == operation
                {
                    state.nextFailure = nil
                    failure = planned.1
                } else {
                    failure = nil
                }
                return (gate, failure)
            }

            gate?.arriveAndWait()
            if let failure {
                throw failure
            }
            return state.withLock { body(&$0) }
        }
    }
}

final class SessionStorageOperationGate: Sendable {
    private struct State: Sendable {
        var didArrive = false
        var isOpen = false
        var arrivalWaiters: [CheckedContinuation<Void, Never>] = []
    }

    private let state = Mutex(State())
    private let releaseCondition = NSCondition()

    func waitUntilArrived() async {
        guard state.withLock({ $0.didArrive }) == false else {
            return
        }

        await withCheckedContinuation { continuation in
            let shouldResume = state.withLock { state in
                guard state.didArrive == false else {
                    return true
                }
                state.arrivalWaiters.append(continuation)
                return false
            }
            if shouldResume {
                continuation.resume()
            }
        }
    }

    func open() {
        state.withLock {
            $0.isOpen = true
        }
        releaseCondition.lock()
        releaseCondition.broadcast()
        releaseCondition.unlock()
    }

    fileprivate func arriveAndWait() {
        let waiters = state.withLock { state in
            state.didArrive = true
            defer { state.arrivalWaiters.removeAll() }
            return state.arrivalWaiters
        }
        for waiter in waiters {
            waiter.resume()
        }

        releaseCondition.lock()
        while state.withLock({ $0.isOpen == false }) {
            releaseCondition.wait()
        }
        releaseCondition.unlock()
    }
}
