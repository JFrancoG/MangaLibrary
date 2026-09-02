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
    @Test("A failed activation never publishes a partial session")
    func failedActivationLeavesStorageEmpty() async throws(any Error) {
        let storage = ControlledSessionPersistenceStorage()
        storage.failNext(.save, with: .keychainFailure(-34_018))
        let persistence = SessionPersistenceActor(operations: storage.operations())
        let session = try makeSession()

        await #expect(throws: SessionStorageError.keychainFailure(-34_018)) {
            try await persistence.activate(
                userID: session.userID,
                generation: session.generation,
                access: session.access
            )
        }

        #expect(storage.snapshot().record == nil)
    }

    @Test("An unavailable Keychain is never interpreted as signed out")
    func unavailableRestorePreservesTheRecord() async throws(any Error) {
        let session = try makeSession()
        let storage = ControlledSessionPersistenceStorage(record: session)
        storage.failNext(.load, with: .temporarilyUnavailable)
        let persistence = SessionPersistenceActor(operations: storage.operations())

        await #expect(throws: SessionStorageError.temporarilyUnavailable) {
            try await persistence.restore()
        }

        #expect(storage.snapshot().record == session)
        #expect(storage.snapshot().journal == [.load])
    }

    @Test("A failed legacy cleanup never publishes the current V3 authority")
    func failedLegacyCleanupDefersRestore() async throws(any Error) {
        let session = try makeSession()
        let storage = ControlledSessionPersistenceStorage(record: session)
        storage.failNext(.removeLegacy, with: .temporarilyUnavailable)
        let persistence = SessionPersistenceActor(operations: storage.operations())

        await #expect(throws: SessionStorageError.temporarilyUnavailable) {
            try await persistence.restore()
        }

        #expect(storage.snapshot().record == session)
        #expect(storage.snapshot().journal == [.load, .removeLegacy])
    }

    @Test("A corrupt Keychain record is removed and fails closed")
    func corruptRestoreDeletesTheUnusableRecord() async throws(any Error) {
        let storage = ControlledSessionPersistenceStorage(record: try makeSession())
        storage.failNext(.load, with: .corruptSessionRecord)
        let persistence = SessionPersistenceActor(operations: storage.operations())

        #expect(try await persistence.restore() == .signedOut)
        #expect(storage.snapshot().record == nil)
        #expect(storage.snapshot().journal == [.load, .removeAll])
    }

    @Test("A failed access update preserves the complete previous session")
    func failedRefreshWriteKeepsThePreviousRecord() async throws(any Error) {
        let session = try makeSession()
        let storage = ControlledSessionPersistenceStorage(record: session)
        storage.failNext(.save, with: .keychainFailure(-34_018))
        let persistence = SessionPersistenceActor(operations: storage.operations())
        let renewedAccess = SessionCredential(
            value: "synthetic-access-renewed",
            expiresAt: Self.issuedAt.addingTimeInterval(86_400)
        )

        await #expect(throws: SessionStorageError.keychainFailure(-34_018)) {
            try await persistence.replaceAccess(renewedAccess, expected: session.authority)
        }

        #expect(storage.snapshot().record == session)
    }

    @Test("A failed logout deletion retains the session and can be retried")
    func failedDeletionLeavesTheCurrentGenerationRetryable() async throws(any Error) {
        let session = try makeSession()
        let storage = ControlledSessionPersistenceStorage(record: session)
        storage.failNext(.removeAll, with: .temporarilyUnavailable)
        let persistence = SessionPersistenceActor(operations: storage.operations())

        await #expect(throws: SessionStorageError.temporarilyUnavailable) {
            try await persistence.remove(expected: session.authority)
        }
        #expect(storage.snapshot().record == session)

        #expect(try await persistence.remove(expected: session.authority))
        #expect(storage.snapshot().record == nil)
    }

    private func makeSession() throws(SessionStorageError) -> SessionPersistedSession {
        try SessionPersistedSession(
            userID: Self.userID,
            generation: Self.generation,
            access: SessionCredential(value: "synthetic-access", expiresAt: Self.issuedAt.addingTimeInterval(86_400))
        )
    }

    private static let issuedAt = Date(timeIntervalSince1970: 1_700_000_000)
    private static let userID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    private static let generation = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
}

enum SessionPersistenceOperation: Equatable, Hashable {
    case load
    case save
    case removeLegacy
    case removeAll
}

final class ControlledSessionPersistenceStorage: Sendable {
    struct Snapshot {
        let record: SessionPersistedSession?
        let journal: [SessionPersistenceOperation]
    }

    private struct State {
        var record: SessionPersistedSession?
        var journal: [SessionPersistenceOperation] = []
        var failures: [SessionPersistenceOperation: [SessionStorageError]] = [:]
        var cancellations: Set<SessionPersistenceOperation> = []
    }

    private let state: Mutex<State>
    private let loadGate: SynchronousPersistenceGate?
    private let removeAllGate: SynchronousPersistenceGate?
    private let saveGate: SynchronousPersistenceGate?

    init(
        record: SessionPersistedSession? = nil,
        loadGate: SynchronousPersistenceGate? = nil,
        removeAllGate: SynchronousPersistenceGate? = nil,
        saveGate: SynchronousPersistenceGate? = nil
    ) {
        state = Mutex(State(record: record))
        self.loadGate = loadGate
        self.removeAllGate = removeAllGate
        self.saveGate = saveGate
    }

    func operations() -> SessionPersistenceActor.Operations {
        SessionPersistenceActor.Operations(
            load: { [self] in
                loadGate?.pause()
                return try perform(.load) { $0.record }
            },
            save: { [self] record in
                saveGate?.pause()
                try perform(.save) { $0.record = record }
            },
            removeLegacy: { [self] in try perform(.removeLegacy) { _ in } },
            removeAll: { [self] in
                removeAllGate?.pause()
                try perform(.removeAll) { $0.record = nil }
            }
        )
    }

    func failNext(_ operation: SessionPersistenceOperation, with error: SessionStorageError) {
        state.withLock { $0.failures[operation, default: []].append(error) }
    }

    func cancelCurrentTaskAfter(_ operation: SessionPersistenceOperation) {
        _ = state.withLock { $0.cancellations.insert(operation) }
    }

    func snapshot() -> Snapshot {
        state.withLock { Snapshot(record: $0.record, journal: $0.journal) }
    }

    private func perform<Value>(
        _ operation: SessionPersistenceOperation,
        body: (inout State) -> Value
    ) throws(any Error) -> Value {
        let (value, shouldCancel) = try state.withLock { state in
            state.journal.append(operation)
            if var failures = state.failures[operation], failures.isEmpty == false {
                let error = failures.removeFirst()
                state.failures[operation] = failures
                throw error
            }
            return (body(&state), state.cancellations.remove(operation) != nil)
        }
        if shouldCancel { withUnsafeCurrentTask { $0?.cancel() } }
        return value
    }
}

final class SynchronousPersistenceGate: Sendable {
    private let entered = Atomic(false)
    private let isOpen = Atomic(false)

    func pause() {
        entered.store(true, ordering: .releasing)
        while isOpen.load(ordering: .acquiring) == false {}
    }

    func waitUntilEntered() async {
        while entered.load(ordering: .acquiring) == false { await Task.yield() }
    }

    func open() {
        isOpen.store(true, ordering: .releasing)
    }
}
