//
//  SessionPersistenceActor.swift
//  MangaLibrary
//

import Foundation

/// Serializes every durable transition across the Keychain and session ledger.
actor SessionPersistenceActor {
    struct Operations: Sendable {
        let readLedger: @Sendable () throws(any Error) -> SessionLedgerRecord?
        let writeLedger: @Sendable (SessionLedgerRecord) throws(any Error) -> Void
        let removeLedger: @Sendable () throws(any Error) -> Void
        let readBundle: @Sendable (UUID) throws(any Error) -> SessionSecretBundle?
        let writeBundle: @Sendable (SessionSecretBundle) throws(any Error) -> Void
        let removeBundle: @Sendable (UUID) throws(any Error) -> Void
        let removeAllBundles: @Sendable () throws(any Error) -> Void

        static func live(keychain: SessionKeychainStore, ledger: SessionLedgerStore) -> Self {
            Self(
                readLedger: { try ledger.read() },
                writeLedger: { try ledger.write($0) },
                removeLedger: { try ledger.remove() },
                readBundle: { try keychain.load(generation: $0) },
                writeBundle: { try keychain.save($0) },
                removeBundle: { try keychain.remove(generation: $0) },
                removeAllBundles: { try keychain.removeAll() }
            )
        }
    }

    private let operations: Operations

    init(keychain: SessionKeychainStore, ledger: SessionLedgerStore) {
        operations = .live(keychain: keychain, ledger: ledger)
    }

    init(operations: Operations) {
        self.operations = operations
    }

    static func live() throws(SessionStorageError) -> SessionPersistenceActor {
        try SessionPersistenceActor(
            keychain: .live(),
            ledger: .live()
        )
    }

    /// Restores durable session state only when its exact generation has a valid bundle.
    ///
    /// A protected store that is temporarily unavailable is propagated without
    /// mutating either store, so device lock can never be mistaken for absence.
    func restore() throws(any Error) -> SessionRestoration {
        let record: SessionLedgerRecord?
        do {
            record = try operations.readLedger()
        } catch SessionStorageError.corruptLedger {
            try operations.removeLedger()
            try operations.removeAllBundles()
            return .signedOut
        }

        guard let record else {
            try operations.removeAllBundles()
            return .signedOut
        }

        switch record.phase {
        case .active, .logoutPrepared:
            guard let generation = record.sessionGeneration else {
                throw SessionPersistenceError.inconsistentAuthority
            }

            let bundle: SessionSecretBundle?
            do {
                bundle = try operations.readBundle(generation)
            } catch SessionStorageError.corruptSecretBundle {
                return try finishAuthenticationRequirement(from: record)
            }

            guard let bundle else {
                return try finishAuthenticationRequirement(from: record)
            }

            let session = SessionPersistedSession(
                authority: authority(from: record, generation: generation),
                bundle: bundle
            )
            if record.phase == .active {
                return .active(session)
            }
            return .logoutPrepared(session)

        case .invalidatedCleanupPending:
            return try completePendingCleanup(record)

        case .authenticationRequired:
            try operations.removeAllBundles()
            return .authenticationRequired(record.userID)
        }
    }

    /// Activates a generation only after its secret bundle is durable.
    func activate(
        userID: UUID,
        generation: UUID,
        access: SessionCredential,
        refresh: SessionCredential
    ) throws(any Error) -> SessionPersistedSession {
        let existing = try operations.readLedger()
        let revision: UInt64
        switch existing?.phase {
        case nil:
            try operations.removeAllBundles()
            revision = 1
        case .authenticationRequired:
            guard let existing else {
                throw SessionPersistenceError.inconsistentAuthority
            }
            try operations.removeAllBundles()
            revision = try increment(existing.revision)
        case .active, .logoutPrepared, .invalidatedCleanupPending:
            throw SessionPersistenceError.transitionBlocked
        }

        let bundle = try SessionSecretBundle(
            generation: generation,
            access: access,
            refresh: refresh
        )

        try operations.writeBundle(bundle)
        let active = SessionLedgerRecord.active(
            userID: userID,
            generation: generation,
            revision: revision
        )
        do {
            try operations.writeLedger(active)
        } catch {
            try? operations.removeBundle(generation)
            throw error
        }

        return SessionPersistedSession(
            authority: authority(from: active, generation: generation),
            bundle: bundle
        )
    }

    /// Replaces only the access credential for the exact active authority.
    func replaceAccess(
        _ access: SessionCredential,
        expected: SessionAuthority
    ) throws(any Error) -> SessionPersistedSession? {
        guard
            access.use == .access,
            access.value.isEmpty == false,
            access.expiresAt.timeIntervalSinceReferenceDate.isFinite
        else {
            throw SessionStorageError.corruptSecretBundle
        }
        guard
            let record = try operations.readLedger(),
            record.phase == .active,
            matches(record, expected: expected)
        else {
            return nil
        }
        guard let current = try operations.readBundle(expected.generation) else {
            throw SessionStorageError.corruptSecretBundle
        }

        let replacement = try SessionSecretBundle(
            generation: expected.generation,
            access: access,
            refresh: current.refresh
        )
        try operations.writeBundle(replacement)
        return SessionPersistedSession(
            authority: expected,
            bundle: replacement
        )
    }

    /// Starts the cancelable logout phase while reserving room for invalidation.
    func prepareLogout(expected: SessionAuthority) throws(any Error) -> SessionAuthority? {
        guard
            let record = try operations.readLedger(),
            record.phase == .active,
            matches(record, expected: expected)
        else {
            return nil
        }

        let preparedRevision = try increment(record.revision)
        _ = try increment(preparedRevision)
        let prepared = SessionLedgerRecord.logoutPrepared(
            userID: record.userID,
            generation: expected.generation,
            revision: preparedRevision
        )
        try operations.writeLedger(prepared)
        return authority(from: prepared, generation: expected.generation)
    }

    /// Cancels only the exact logout ticket before local invalidation.
    func cancelLogout(expected: SessionAuthority) throws(any Error) -> SessionPersistedSession? {
        guard
            let record = try operations.readLedger(),
            record.phase == .logoutPrepared,
            matches(record, expected: expected)
        else {
            return nil
        }
        guard let bundle = try operations.readBundle(expected.generation) else {
            throw SessionStorageError.corruptSecretBundle
        }

        let active = SessionLedgerRecord.active(
            userID: record.userID,
            generation: expected.generation,
            revision: try increment(record.revision)
        )
        try operations.writeLedger(active)
        return SessionPersistedSession(
            authority: authority(from: active, generation: expected.generation),
            bundle: bundle
        )
    }

    /// Crosses logout's point of no return and conditionally removes A only.
    func completeLogout(expected: SessionAuthority) throws(any Error) -> Bool {
        guard let ticket = try invalidateLogout(expected: expected) else {
            return false
        }
        return try completeCleanup(expected: ticket) == .signedOut
    }

    /// Persists logout's point of no return without starting cleanup yet.
    func invalidateLogout(expected: SessionAuthority) throws(any Error) -> SessionCleanupTicket? {
        guard
            let record = try operations.readLedger(),
            record.phase == .logoutPrepared,
            matches(record, expected: expected)
        else {
            return nil
        }

        let pending = SessionLedgerRecord.cleanupPending(
            userID: record.userID,
            generation: expected.generation,
            revision: try increment(record.revision),
            completion: .signedOut
        )
        try operations.writeLedger(pending)
        return SessionCleanupTicket(
            userID: record.userID,
            generation: expected.generation,
            revision: pending.revision,
            completion: .signedOut
        )
    }

    /// Invalidates a permanently rejected refresh while retaining only user scope.
    func markAuthenticationRequired(expected: SessionAuthority) throws(any Error) -> Bool {
        guard
            let ticket = try invalidateForAuthentication(expected: expected)
        else {
            return false
        }
        return try completeCleanup(expected: ticket)
            == .authenticationRequired(ticket.userID)
    }

    /// Persists permanent authentication invalidation before deleting its bundle.
    func invalidateForAuthentication(expected: SessionAuthority) throws(any Error) -> SessionCleanupTicket? {
        guard
            let record = try operations.readLedger(),
            record.phase == .active,
            matches(record, expected: expected)
        else {
            return nil
        }

        let pendingRevision = try increment(record.revision)
        _ = try increment(pendingRevision)
        let pending = SessionLedgerRecord.cleanupPending(
            userID: record.userID,
            generation: expected.generation,
            revision: pendingRevision,
            completion: .authenticationRequired
        )
        try operations.writeLedger(pending)
        return SessionCleanupTicket(
            userID: record.userID,
            generation: expected.generation,
            revision: pending.revision,
            completion: .authenticationRequired
        )
    }

    /// Completes only the exact cleanup ticket; a newer ledger is a no-op.
    func completeCleanup(expected ticket: SessionCleanupTicket) throws(any Error) -> SessionRestoration? {
        let record = ticket.ledgerRecord
        guard try operations.readLedger() == record else {
            return nil
        }
        try operations.removeBundle(ticket.generation)
        guard try operations.readLedger() == record else {
            return nil
        }

        switch ticket.completion {
        case .signedOut:
            try operations.removeLedger()
            return .signedOut
        case .authenticationRequired:
            let final = SessionLedgerRecord.authenticationRequired(
                userID: ticket.userID,
                revision: try increment(record.revision)
            )
            try operations.writeLedger(final)
            return .authenticationRequired(ticket.userID)
        }
    }

    private func completePendingCleanup(_ record: SessionLedgerRecord) throws(any Error) -> SessionRestoration {
        guard
            let generation = record.sessionGeneration,
            let completion = record.cleanupCompletion
        else {
            throw SessionPersistenceError.inconsistentAuthority
        }
        let ticket = SessionCleanupTicket(
            userID: record.userID,
            generation: generation,
            revision: record.revision,
            completion: completion
        )
        guard let restoration = try completeCleanup(expected: ticket) else {
            throw SessionPersistenceError.inconsistentAuthority
        }
        return restoration
    }

    private func finishAuthenticationRequirement(
        from record: SessionLedgerRecord
    ) throws(any Error) -> SessionRestoration {
        guard let generation = record.sessionGeneration else {
            throw SessionPersistenceError.inconsistentAuthority
        }

        let pendingRevision = try increment(record.revision)
        let finalRevision = try increment(pendingRevision)
        let pending = SessionLedgerRecord.cleanupPending(
            userID: record.userID,
            generation: generation,
            revision: pendingRevision,
            completion: .authenticationRequired
        )
        try operations.writeLedger(pending)
        try operations.removeBundle(generation)

        guard try operations.readLedger() == pending else {
            throw SessionPersistenceError.inconsistentAuthority
        }
        try operations.writeLedger(
            .authenticationRequired(
                userID: record.userID,
                revision: finalRevision
            )
        )
        return .authenticationRequired(record.userID)
    }

    private func matches(_ record: SessionLedgerRecord, expected: SessionAuthority) -> Bool {
        record.userID == expected.userID
            && record.sessionGeneration == expected.generation
            && record.revision == expected.revision
    }

    private func authority(from record: SessionLedgerRecord, generation: UUID) -> SessionAuthority {
        SessionAuthority(
            userID: record.userID,
            generation: generation,
            revision: record.revision
        )
    }

    private func increment(_ revision: UInt64) throws(SessionPersistenceError) -> UInt64 {
        let (next, overflow) = revision.addingReportingOverflow(1)
        guard overflow == false else {
            throw SessionPersistenceError.revisionExhausted
        }
        return next
    }
}
