//
//  SessionKeychainStore.swift
//  MangaLibrary
//

import Foundation
import Security

/// Stores the complete current session in one non-synchronizable Keychain item.
struct SessionKeychainStore {
    static let account = "current-session"

    let service: String
    let legacyServices: [String]

    static func live() throws(SessionStorageError) -> Self {
        guard
            let bundleIdentifier = Bundle.main.bundleIdentifier,
            bundleIdentifier.isEmpty == false
        else { throw SessionStorageError.invalidConfiguration }

        return Self(
            service: "\(bundleIdentifier).session.current.v3",
            legacyServices: [
                "\(bundleIdentifier).session-secrets.v1",
                "\(bundleIdentifier).session.current.v2",
            ]
        )
    }

    func save(_ session: SessionPersistedSession) throws(SessionStorageError) {
        try validateConfiguration()

        let data: Data
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            data = try encoder.encode(SessionEnvelopeV3(session: session))
        } catch {
            throw SessionStorageError.encodingFailure
        }

        let attributes: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: Self.account,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable: false,
            kSecValueData: data,
        ]
        let addStatus = SecItemAdd(attributes as CFDictionary, nil)
        switch addStatus {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let updateStatus = SecItemUpdate(
                query(service: service) as CFDictionary,
                [kSecValueData: data] as CFDictionary
            )
            guard updateStatus == errSecSuccess else { throw storageError(for: updateStatus) }
        default:
            throw storageError(for: addStatus)
        }
    }

    func load() throws(SessionStorageError) -> SessionPersistedSession? {
        try validateConfiguration()

        var query = query(service: service)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { throw SessionStorageError.corruptSessionRecord }
            do {
                return try JSONDecoder().decode(SessionEnvelopeV3.self, from: data).session()
            } catch let error as SessionStorageError {
                throw error
            } catch {
                throw SessionStorageError.corruptSessionRecord
            }
        case errSecItemNotFound:
            return nil
        default:
            throw storageError(for: status)
        }
    }

    /// Removes the current item and every explicitly known legacy namespace.
    func removeAll() throws(SessionStorageError) {
        try validateConfiguration()

        try removeItems(in: legacyServices.filter { $0 != service } + [service])
    }

    /// Removes every known legacy namespace without changing the current V3 item.
    func removeLegacy() throws(SessionStorageError) {
        try validateConfiguration()

        try removeItems(in: legacyServices.filter { $0 != service })
    }

    private func removeItems(in services: [String]) throws(SessionStorageError) {
        for service in services where service.isEmpty == false {
            let query: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrSynchronizable: kSecAttrSynchronizableAny,
            ]
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw storageError(for: status) }
        }
    }

    private func query(service: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: Self.account,
            kSecAttrSynchronizable: false,
        ]
    }

    private func validateConfiguration() throws(SessionStorageError) {
        guard service.isEmpty == false else { throw SessionStorageError.invalidConfiguration }
    }

    private func storageError(for status: OSStatus) -> SessionStorageError {
        if status == errSecInteractionNotAllowed || status == errSecNotAvailable {
            return .temporarilyUnavailable
        }
        return .keychainFailure(status)
    }
}

private struct SessionEnvelopeV3: Codable {
    let formatVersion: Int
    let userID: UUID
    let generation: UUID
    let token: String
    let expiresAt: Date

    func session() throws(SessionStorageError) -> SessionPersistedSession {
        guard formatVersion == SessionPersistedSession.currentFormatVersion else {
            throw SessionStorageError.corruptSessionRecord
        }

        return try SessionPersistedSession(
            userID: userID,
            generation: generation,
            access: SessionCredential(value: token, expiresAt: expiresAt)
        )
    }
}

private extension SessionEnvelopeV3 {
    init(session: SessionPersistedSession) {
        formatVersion = SessionPersistedSession.currentFormatVersion
        userID = session.userID
        generation = session.generation
        token = session.access.value
        expiresAt = session.access.expiresAt
    }
}
