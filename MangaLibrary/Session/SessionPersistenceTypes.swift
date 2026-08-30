//
//  SessionPersistenceTypes.swift
//  MangaLibrary
//

import Foundation

enum SessionStorageError: Error, Equatable, Sendable {
    case invalidConfiguration
    case encodingFailure
    case temporarilyUnavailable
    case keychainFailure(Int32)
    case corruptSecretBundle
    case corruptLedger
    case fileSystemFailure
}

/// The only value persisted as Keychain data for one opaque session generation.
struct SessionSecretBundle: Equatable, Sendable {
    static let currentFormatVersion = 1

    private let formatVersion: Int
    let generation: UUID
    let access: SessionCredential
    let refresh: SessionCredential
}

extension SessionSecretBundle {
    init(generation: UUID, access: SessionCredential, refresh: SessionCredential) throws(SessionStorageError) {
        guard
            access.use == .access,
            access.value.isEmpty == false,
            access.expiresAt.timeIntervalSinceReferenceDate.isFinite,
            refresh.use == .refresh,
            refresh.value.isEmpty == false,
            refresh.expiresAt.timeIntervalSinceReferenceDate.isFinite
        else {
            throw SessionStorageError.corruptSecretBundle
        }

        self.init(
            formatVersion: Self.currentFormatVersion,
            generation: generation,
            access: access,
            refresh: refresh
        )
    }
}

enum SessionLedgerPhase: String, Codable, Equatable, Sendable {
    case active
    case logoutPrepared
    case invalidatedCleanupPending
    case authenticationRequired
}

enum SessionCleanupCompletion: String, Codable, Equatable, Sendable {
    case signedOut
    case authenticationRequired
}

/// Non-secret durable authority for session restoration and crash recovery.
struct SessionLedgerRecord: Codable, Equatable, Sendable {
    static let currentFormatVersion = 1

    private let formatVersion: Int
    let userID: UUID
    let sessionGeneration: UUID?
    let revision: UInt64
    let phase: SessionLedgerPhase
    let cleanupCompletion: SessionCleanupCompletion?

    static func active(userID: UUID, generation: UUID, revision: UInt64) -> Self {
        Self(
            formatVersion: currentFormatVersion,
            userID: userID,
            sessionGeneration: generation,
            revision: revision,
            phase: .active,
            cleanupCompletion: nil
        )
    }

    static func logoutPrepared(userID: UUID, generation: UUID, revision: UInt64) -> Self {
        Self(
            formatVersion: currentFormatVersion,
            userID: userID,
            sessionGeneration: generation,
            revision: revision,
            phase: .logoutPrepared,
            cleanupCompletion: nil
        )
    }

    static func cleanupPending(
        userID: UUID,
        generation: UUID,
        revision: UInt64,
        completion: SessionCleanupCompletion
    ) -> Self {
        Self(
            formatVersion: currentFormatVersion,
            userID: userID,
            sessionGeneration: generation,
            revision: revision,
            phase: .invalidatedCleanupPending,
            cleanupCompletion: completion
        )
    }

    static func authenticationRequired(userID: UUID, revision: UInt64) -> Self {
        Self(
            formatVersion: currentFormatVersion,
            userID: userID,
            sessionGeneration: nil,
            revision: revision,
            phase: .authenticationRequired,
            cleanupCompletion: nil
        )
    }
}

extension SessionLedgerRecord {
    private enum CodingKeys: String, CodingKey {
        case formatVersion
        case userID
        case sessionGeneration
        case revision
        case phase
        case cleanupCompletion
    }

    init(from decoder: any Decoder) throws(any Error) {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let formatVersion = try values.decode(Int.self, forKey: .formatVersion)
        let userID = try values.decode(UUID.self, forKey: .userID)
        let sessionGeneration = try values.decodeIfPresent(
            UUID.self,
            forKey: .sessionGeneration
        )
        let revision = try values.decode(UInt64.self, forKey: .revision)
        let phase = try values.decode(SessionLedgerPhase.self, forKey: .phase)
        let cleanupCompletion = try values.decodeIfPresent(
            SessionCleanupCompletion.self,
            forKey: .cleanupCompletion
        )

        guard
            Self.isValid(
                formatVersion: formatVersion,
                generation: sessionGeneration,
                phase: phase,
                completion: cleanupCompletion
            )
        else {
            throw SessionStorageError.corruptLedger
        }

        self.init(
            formatVersion: formatVersion,
            userID: userID,
            sessionGeneration: sessionGeneration,
            revision: revision,
            phase: phase,
            cleanupCompletion: cleanupCompletion
        )
    }

    private static func isValid(
        formatVersion: Int,
        generation: UUID?,
        phase: SessionLedgerPhase,
        completion: SessionCleanupCompletion?
    ) -> Bool {
        guard formatVersion == currentFormatVersion else {
            return false
        }

        switch phase {
        case .active, .logoutPrepared:
            return generation != nil && completion == nil
        case .invalidatedCleanupPending:
            return generation != nil && completion != nil
        case .authenticationRequired:
            return generation == nil && completion == nil
        }
    }
}

struct SessionAuthority: Equatable, Sendable {
    let userID: UUID
    let generation: UUID
    let revision: UInt64
}

struct SessionPersistedSession: Equatable, Sendable {
    let authority: SessionAuthority
    let bundle: SessionSecretBundle
}

struct SessionCleanupTicket: Equatable, Sendable {
    let userID: UUID
    let generation: UUID
    let revision: UInt64
    let completion: SessionCleanupCompletion

    var ledgerRecord: SessionLedgerRecord {
        .cleanupPending(
            userID: userID,
            generation: generation,
            revision: revision,
            completion: completion
        )
    }
}

enum SessionRestoration: Equatable, Sendable {
    case signedOut
    case active(SessionPersistedSession)
    case logoutPrepared(SessionPersistedSession)
    case authenticationRequired(UUID)
}

enum SessionPersistenceError: Error, Equatable, Sendable {
    case transitionBlocked
    case revisionExhausted
    case inconsistentAuthority
}
