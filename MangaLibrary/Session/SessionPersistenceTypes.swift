//
//  SessionPersistenceTypes.swift
//  MangaLibrary
//

import Foundation
import Synchronization

enum SessionStorageError: Error, Equatable {
    case invalidConfiguration
    case encodingFailure
    case temporarilyUnavailable
    case keychainFailure(Int32)
    case corruptSessionRecord
}

/// The complete versioned session authority stored as one Keychain item.
struct SessionPersistedSession: Equatable {
    static let currentFormatVersion = 2

    private let storedUserID: UUID
    private let storedGeneration: UUID
    private let storedAccess: SessionCredential
    private let storedRefresh: SessionCredential

    var userID: UUID { storedUserID }
    var generation: UUID { storedGeneration }
    var access: SessionCredential { storedAccess }
    var refresh: SessionCredential { storedRefresh }

    var authority: SessionAuthority {
        SessionAuthority(userID: userID, generation: generation)
    }

    func replacingAccess(with access: SessionCredential) throws(SessionStorageError) -> Self {
        try Self(
            userID: userID,
            generation: generation,
            access: access,
            refresh: refresh
        )
    }
}

extension SessionPersistedSession {
    init(
        userID: UUID,
        generation: UUID,
        access: SessionCredential,
        refresh: SessionCredential
    ) throws(SessionStorageError) {
        guard
            access.use == .access,
            access.value.isEmpty == false,
            access.expiresAt.timeIntervalSinceReferenceDate.isFinite,
            refresh.use == .refresh,
            refresh.value.isEmpty == false,
            refresh.expiresAt.timeIntervalSinceReferenceDate.isFinite
        else { throw SessionStorageError.corruptSessionRecord }

        storedUserID = userID
        storedGeneration = generation
        storedAccess = access
        storedRefresh = refresh
    }
}

struct SessionAuthority: Equatable {
    let userID: UUID
    let generation: UUID
}

enum SessionCommitAuthorizationError: Error, Equatable {
    case sessionChanged
}

/// Linearizes session invalidation with one in-process persistence commit.
///
/// The lock is held only around a non-suspending critical section. A session
/// transition either invalidates the authority before that section begins or
/// waits until the already-authorized commit has completed. This is not the
/// durable cross-process `SessionFence` reserved for the Deluxe scope.
final class SessionCommitGate: Sendable {
    private let activeAuthority: Mutex<SessionAuthority?>

    init(activeAuthority: SessionAuthority? = nil) {
        self.activeAuthority = Mutex(activeAuthority)
    }

    func activate(_ authority: SessionAuthority) {
        activeAuthority.withLock { $0 = authority }
    }

    func invalidate(_ authority: SessionAuthority) {
        activeAuthority.withLock {
            if $0 == authority { $0 = nil }
        }
    }

    func invalidateAll() {
        activeAuthority.withLock { $0 = nil }
    }

    func authorizes(_ authority: SessionAuthority) -> Bool {
        activeAuthority.withLock { $0 == authority }
    }

    func authorization(for authority: SessionAuthority) -> SessionCommitAuthorization {
        SessionCommitAuthorization(authority: authority, gate: self)
    }

    fileprivate func withAuthorizedCommit<Result>(
        for authority: SessionAuthority,
        _ commit: () throws -> Result
    ) throws -> Result {
        try activeAuthority.withLock { activeAuthority in
            guard activeAuthority == authority else {
                throw SessionCommitAuthorizationError.sessionChanged
            }

            return try commit()
        }
    }
}

/// One generation-scoped capability consumed at a synchronous commit boundary.
struct SessionCommitAuthorization {
    let authority: SessionAuthority

    private let gate: SessionCommitGate

    fileprivate init(authority: SessionAuthority, gate: SessionCommitGate) {
        self.authority = authority
        self.gate = gate
    }

    func perform<Result>(_ commit: () throws -> Result) throws -> Result {
        try gate.withAuthorizedCommit(for: authority, commit)
    }
}

/// Short-lived authorization for one remote request owned by infrastructure.
///
/// Callers use `authority` for an early rejection and must consume
/// `commitAuthorization` inside their synchronous persistence transaction.
/// The raw token must never enter presentation state, diagnostics or durable
/// storage outside the versioned session record.
struct SessionRequestAuthorization {
    let authority: SessionAuthority
    let accessToken: String
    let commitAuthorization: SessionCommitAuthorization

    init(
        authority: SessionAuthority,
        accessToken: String,
        commitAuthorization: SessionCommitAuthorization
    ) {
        precondition(commitAuthorization.authority == authority)
        self.authority = authority
        self.accessToken = accessToken
        self.commitAuthorization = commitAuthorization
    }
}

enum SessionRestoration: Equatable {
    case signedOut
    case active(SessionPersistedSession)
}

enum SessionPersistenceError: Error, Equatable {
    case transitionBlocked
}
