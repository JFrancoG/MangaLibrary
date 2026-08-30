//
//  SessionKeychainStore.swift
//  MangaLibrary
//

import Foundation
import Security

/// Stores one secret bundle per opaque generation without searchable user data.
struct SessionKeychainStore: Sendable {
    let service: String

    static func live() throws(SessionStorageError) -> Self {
        guard
            let bundleIdentifier = Bundle.main.bundleIdentifier,
            bundleIdentifier.isEmpty == false
        else {
            throw SessionStorageError.invalidConfiguration
        }

        return Self(service: "\(bundleIdentifier).session-secrets.v1")
    }

    func save(_ bundle: SessionSecretBundle) throws(SessionStorageError) {
        guard service.isEmpty == false else {
            throw SessionStorageError.invalidConfiguration
        }

        let data: Data
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            data = try encoder.encode(SessionSecretEnvelopeV1(bundle: bundle))
        } catch {
            throw SessionStorageError.encodingFailure
        }

        let query = query(generation: bundle.generation)
        let attributes: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: bundle.generation.uuidString.lowercased(),
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData: data,
        ]

        let addStatus = SecItemAdd(attributes as CFDictionary, nil)
        switch addStatus {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let updateStatus = SecItemUpdate(
                query as CFDictionary,
                [kSecValueData: data] as CFDictionary
            )
            guard updateStatus == errSecSuccess else {
                throw storageError(for: updateStatus)
            }
        default:
            throw storageError(for: addStatus)
        }
    }

    func load(generation: UUID) throws(SessionStorageError) -> SessionSecretBundle? {
        guard service.isEmpty == false else {
            throw SessionStorageError.invalidConfiguration
        }

        var query = query(generation: generation)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw SessionStorageError.corruptSecretBundle
            }

            do {
                let envelope = try JSONDecoder().decode(
                    SessionSecretEnvelopeV1.self,
                    from: data
                )
                let bundle = try envelope.bundle(
                    expectedGeneration: generation
                )
                return bundle
            } catch let error as SessionStorageError {
                throw error
            } catch {
                throw SessionStorageError.corruptSecretBundle
            }
        case errSecItemNotFound:
            return nil
        case errSecInteractionNotAllowed, errSecNotAvailable:
            throw SessionStorageError.temporarilyUnavailable
        default:
            throw SessionStorageError.keychainFailure(status)
        }
    }

    func remove(generation: UUID) throws(SessionStorageError) {
        guard service.isEmpty == false else {
            throw SessionStorageError.invalidConfiguration
        }

        let status = SecItemDelete(query(generation: generation) as CFDictionary)
        if status == errSecInteractionNotAllowed || status == errSecNotAvailable {
            throw SessionStorageError.temporarilyUnavailable
        }
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SessionStorageError.keychainFailure(status)
        }
    }

    func removeAll() throws(SessionStorageError) {
        guard service.isEmpty == false else {
            throw SessionStorageError.invalidConfiguration
        }

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrSynchronizable: kSecAttrSynchronizableAny,
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecInteractionNotAllowed || status == errSecNotAvailable {
            throw SessionStorageError.temporarilyUnavailable
        }
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SessionStorageError.keychainFailure(status)
        }
    }

    private func query(generation: UUID) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: generation.uuidString.lowercased(),
            kSecAttrSynchronizable: false,
        ]
    }

    private func storageError(for status: OSStatus) -> SessionStorageError {
        if status == errSecInteractionNotAllowed || status == errSecNotAvailable {
            return .temporarilyUnavailable
        }
        return .keychainFailure(status)
    }
}

private struct SessionSecretEnvelopeV1: Codable {
    let formatVersion: Int
    let generation: UUID
    let accessToken: String
    let accessExpiresAt: Date
    let refreshToken: String
    let refreshExpiresAt: Date

    func bundle(expectedGeneration: UUID) throws(SessionStorageError) -> SessionSecretBundle {
        guard
            formatVersion == SessionSecretBundle.currentFormatVersion,
            generation == expectedGeneration
        else {
            throw SessionStorageError.corruptSecretBundle
        }

        return try SessionSecretBundle(
            generation: generation,
            access: SessionCredential(
                value: accessToken,
                use: .access,
                expiresAt: accessExpiresAt
            ),
            refresh: SessionCredential(
                value: refreshToken,
                use: .refresh,
                expiresAt: refreshExpiresAt
            )
        )
    }
}

extension SessionSecretEnvelopeV1 {
    init(bundle: SessionSecretBundle) {
        formatVersion = SessionSecretBundle.currentFormatVersion
        generation = bundle.generation
        accessToken = bundle.access.value
        accessExpiresAt = bundle.access.expiresAt
        refreshToken = bundle.refresh.value
        refreshExpiresAt = bundle.refresh.expiresAt
    }
}
