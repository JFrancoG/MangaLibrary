//
//  SessionPersistenceTypes.swift
//  MangaLibrary
//

import Foundation

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

enum SessionRestoration: Equatable {
    case signedOut
    case active(SessionPersistedSession)
}

enum SessionPersistenceError: Error, Equatable {
    case transitionBlocked
}
