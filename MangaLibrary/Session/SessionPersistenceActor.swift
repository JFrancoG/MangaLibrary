//
//  SessionPersistenceActor.swift
//  MangaLibrary
//

import Foundation

/// Serializes every mutation of the single durable Keychain session.
actor SessionPersistenceActor {
    struct Operations {
        let load: @Sendable () throws(any Error) -> SessionPersistedSession?
        let save: @Sendable (SessionPersistedSession) throws(any Error) -> Void
        let removeAll: @Sendable () throws(any Error) -> Void

        static func live(keychain: SessionKeychainStore) -> Self {
            Self(
                load: { try keychain.load() },
                save: { try keychain.save($0) },
                removeAll: { try keychain.removeAll() }
            )
        }
    }

    private let operations: Operations

    init(keychain: SessionKeychainStore) {
        operations = .live(keychain: keychain)
    }

    init(operations: Operations) {
        self.operations = operations
    }

    static func live() throws(SessionStorageError) -> SessionPersistenceActor {
        try SessionPersistenceActor(keychain: .live())
    }

    /// Restores the one complete record or fails closed when its payload is corrupt.
    func restore() throws(any Error) -> SessionRestoration {
        do {
            guard let session = try operations.load() else {
                try operations.removeAll()
                return .signedOut
            }
            return .active(session)
        } catch SessionStorageError.corruptSessionRecord {
            try operations.removeAll()
            return .signedOut
        }
    }

    /// Publishes a generation only after the complete Keychain record is durable.
    func activate(
        userID: UUID,
        generation: UUID,
        access: SessionCredential,
        refresh: SessionCredential,
        replacing expected: SessionAuthority? = nil
    ) throws(any Error) -> SessionPersistedSession {
        if let current = try operations.load() {
            guard let expected, current.authority == expected else { throw SessionPersistenceError.transitionBlocked }
        }

        try operations.removeAll()
        let session = try SessionPersistedSession(
            userID: userID,
            generation: generation,
            access: access,
            refresh: refresh
        )
        try operations.save(session)
        return session
    }

    /// Replaces access only while the expected generation remains authoritative.
    func replaceAccess(
        _ access: SessionCredential,
        expected: SessionAuthority
    ) throws(any Error) -> SessionPersistedSession? {
        guard let current = try operations.load(), current.authority == expected else {
            return nil
        }

        let replacement = try current.replacingAccess(with: access)
        try operations.save(replacement)
        return replacement
    }

    /// Deletes only the expected generation and all known legacy session items.
    func remove(expected: SessionAuthority) throws(any Error) -> Bool {
        guard let current = try operations.load(), current.authority == expected else {
            return false
        }

        try operations.removeAll()
        return true
    }
}
