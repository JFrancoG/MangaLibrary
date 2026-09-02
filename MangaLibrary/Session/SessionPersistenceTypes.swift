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
    static let currentFormatVersion = 3

    private let storedUserID: UUID
    private let storedGeneration: UUID
    private let storedAccess: SessionCredential

    var userID: UUID { storedUserID }
    var generation: UUID { storedGeneration }
    var access: SessionCredential { storedAccess }

    var authority: SessionAuthority {
        SessionAuthority(userID: userID, generation: generation)
    }

    func replacingAccess(with access: SessionCredential) throws(SessionStorageError) -> Self {
        try Self(userID: userID, generation: generation, access: access)
    }
}

extension SessionPersistedSession {
    init(userID: UUID, generation: UUID, access: SessionCredential) throws(SessionStorageError) {
        guard
            access.value.isEmpty == false,
            access.expiresAt.timeIntervalSinceReferenceDate.isFinite
        else { throw SessionStorageError.corruptSessionRecord }

        storedUserID = userID
        storedGeneration = generation
        storedAccess = access
    }
}

struct SessionAuthority: Equatable, Hashable {
    let userID: UUID
    let generation: UUID
}

enum SessionCommitAuthorizationError: Error, Equatable {
    case sessionChanged
    case credentialExpired
}

fileprivate final class SessionCommitCredentialIdentity: Sendable {}

/// Linearizes session invalidation with one in-process persistence commit.
///
/// The lock is held only around a non-suspending critical section. A session
/// transition either invalidates the authority before that section begins or
/// waits until the already-authorized commit has completed. This is not the
/// durable cross-process `SessionFence` reserved for the Deluxe scope.
final class SessionCommitGate: Sendable {
    typealias Clock = @Sendable () -> Date

    private struct ActiveSession {
        let authority: SessionAuthority
        let expiresAt: Date
        let credentialIdentity: SessionCommitCredentialIdentity
        let isEnabled: Bool
    }

    private let activeSession: Mutex<ActiveSession?>
    private let now: Clock

    init(
        activeAuthority: SessionAuthority? = nil,
        expiresAt: Date = .distantFuture,
        now: @escaping Clock = { Date() }
    ) {
        activeSession = Mutex(
            activeAuthority.map {
                ActiveSession(
                    authority: $0,
                    expiresAt: expiresAt,
                    credentialIdentity: SessionCommitCredentialIdentity(),
                    isEnabled: true
                )
            }
        )
        self.now = now
    }

    func activate(_ authority: SessionAuthority, expiresAt: Date = .distantFuture) {
        activeSession.withLock {
            $0 = ActiveSession(
                authority: authority,
                expiresAt: expiresAt,
                credentialIdentity: SessionCommitCredentialIdentity(),
                isEnabled: true
            )
        }
    }

    func suspend(_ authority: SessionAuthority) {
        activeSession.withLock { activeSession in
            guard let current = activeSession, current.authority == authority else { return }
            activeSession = ActiveSession(
                authority: current.authority,
                expiresAt: current.expiresAt,
                credentialIdentity: current.credentialIdentity,
                isEnabled: false
            )
        }
    }

    func invalidate(_ authority: SessionAuthority) {
        activeSession.withLock {
            if $0?.authority == authority {
                $0 = nil
            }
        }
    }

    func invalidateAll() {
        activeSession.withLock { $0 = nil }
    }

    func authorizes(_ authority: SessionAuthority) -> Bool {
        activeSession.withLock { $0?.authority == authority && $0?.isEnabled == true }
    }

    func authorizes(_ authorization: SessionCommitAuthorization) -> Bool {
        activeSession.withLock { activeSession in
            activeSession?.authority == authorization.authority
                && activeSession?.credentialIdentity === authorization.credentialIdentity
                && activeSession?.isEnabled == true
        }
    }

    func matches(_ authorization: SessionCommitAuthorization) -> Bool {
        activeSession.withLock { activeSession in
            activeSession?.authority == authorization.authority
                && activeSession?.credentialIdentity === authorization.credentialIdentity
        }
    }

    func authorization(for authority: SessionAuthority) -> SessionCommitAuthorization {
        let credentialIdentity = activeSession.withLock { activeSession in
            guard activeSession?.authority == authority, activeSession?.isEnabled == true else {
                return SessionCommitCredentialIdentity()
            }

            return activeSession?.credentialIdentity ?? SessionCommitCredentialIdentity()
        }
        return SessionCommitAuthorization(authority: authority, credentialIdentity: credentialIdentity, gate: self)
    }

    fileprivate func withAuthorizedCommit<Result>(
        for authority: SessionAuthority,
        credentialIdentity: SessionCommitCredentialIdentity,
        _ commit: () throws -> Result
    ) throws -> Result {
        try activeSession.withLock { activeSession in
            guard
                activeSession?.authority == authority,
                activeSession?.credentialIdentity === credentialIdentity,
                activeSession?.isEnabled == true
            else {
                throw SessionCommitAuthorizationError.sessionChanged
            }
            guard let expiresAt = activeSession?.expiresAt, expiresAt > now() else {
                activeSession = nil
                throw SessionCommitAuthorizationError.credentialExpired
            }

            return try commit()
        }
    }
}

/// One generation-and-credential-scoped capability consumed at a synchronous commit boundary.
struct SessionCommitAuthorization {
    let authority: SessionAuthority

    fileprivate let credentialIdentity: SessionCommitCredentialIdentity
    private let gate: SessionCommitGate

    fileprivate init(
        authority: SessionAuthority,
        credentialIdentity: SessionCommitCredentialIdentity,
        gate: SessionCommitGate
    ) {
        self.authority = authority
        self.credentialIdentity = credentialIdentity
        self.gate = gate
    }

    func perform<Result>(_ commit: () throws -> Result) throws -> Result {
        try gate.withAuthorizedCommit(for: authority, credentialIdentity: credentialIdentity, commit)
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

    init(authority: SessionAuthority, accessToken: String, commitAuthorization: SessionCommitAuthorization) {
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
