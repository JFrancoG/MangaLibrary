//
//  SessionPersistenceStoreTests.swift
//  MangaLibraryTests
//

import Foundation
import Security
import Testing
@testable import MangaLibrary

@Suite("Session Keychain store", .tags(.integration))
struct SessionPersistenceStoreTests {
    @Test("Live Keychain wiring uses V3 and both known legacy namespaces")
    func liveStoreUsesTheVersionedNamespaces() throws(any Error) {
        let bundleIdentifier = try #require(Bundle.main.bundleIdentifier)
        let store = try SessionKeychainStore.live()

        #expect(store.service == "\(bundleIdentifier).session.current.v3")
        #expect(
            store.legacyServices
                == [
                    "\(bundleIdentifier).session-secrets.v1",
                    "\(bundleIdentifier).session.current.v2",
                ]
        )
    }

    @Test("Keychain keeps only the current versioned session")
    func keychainReplacesThePreviousSession() throws(any Error) {
        let service = "com.mangalibrary.tests.session.\(UUID().uuidString)"
        let store = SessionKeychainStore(service: service, legacyServices: [])
        defer { try? store.removeAll() }
        let previous = try makeSession(userID: Self.userA, generation: Self.generationA)
        let current = try makeSession(
            userID: Self.userB,
            generation: Self.generationB,
            accessValue: "synthetic-access-b"
        )

        try store.save(previous)
        try store.save(current)

        #expect(try store.load() == current)
        #expect(try keychainItemCount(service: service) == 1)
    }

    @Test("The current item uses protected non-identifying attributes")
    func keychainAttributesDoNotExposeSessionIdentity() throws(any Error) {
        let service = "com.mangalibrary.tests.session.\(UUID().uuidString)"
        let store = SessionKeychainStore(service: service, legacyServices: [])
        defer { try? store.removeAll() }
        let session = try makeSession(userID: Self.userA, generation: Self.generationA)

        try store.save(session)

        let attributes = try keychainAttributes(service: service)
        #expect(attributes[kSecAttrService as String] as? String == service)
        #expect(attributes[kSecAttrAccount as String] as? String == SessionKeychainStore.account)
        #expect(
            attributes[kSecAttrAccessible as String] as? String
                == kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String
        )
        let searchableAttributes = String(describing: attributes.filter { $0.key != kSecValueData as String })
        #expect(searchableAttributes.contains(Self.userA.uuidString) == false)
        #expect(searchableAttributes.contains(Self.generationA.uuidString) == false)
        #expect(searchableAttributes.contains("example.invalid") == false)

        let storedData = try #require(attributes[kSecValueData as String] as? Data)
        let storedJSON = try #require(String(data: storedData, encoding: .utf8))
        #expect(storedJSON.contains("\"formatVersion\":3"))
        #expect(storedJSON.contains(Self.userA.uuidString.uppercased()))
        #expect(storedJSON.contains("\"token\":\"synthetic-access-a\""))
        #expect(storedJSON.contains("accessToken") == false)
        #expect(storedJSON.contains("refreshToken") == false)
        #expect(storedJSON.contains("email") == false)
        #expect(storedJSON.contains("password") == false)
        #expect(storedJSON.contains("role") == false)
    }

    @Test(
        "Invalid Keychain envelopes cannot become a session",
        arguments: [
            InvalidSessionEnvelopeFixture("missing fields", json: #"{"formatVersion":3}"#),
            InvalidSessionEnvelopeFixture(
                "legacy V2 dual envelope",
                json: #"""
                    {
                      "accessExpiresAt": 700003600,
                      "accessToken": "synthetic-access",
                      "formatVersion": 2,
                      "generation": "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
                      "refreshExpiresAt": 702592000,
                      "refreshToken": "synthetic-refresh",
                      "userID": "11111111-2222-3333-4444-555555555555"
                    }
                    """#
            ),
            InvalidSessionEnvelopeFixture(
                "unknown version",
                json: #"""
                    {
                      "expiresAt": 700086400,
                      "formatVersion": 99,
                      "generation": "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
                      "token": "synthetic-jwt",
                      "userID": "11111111-2222-3333-4444-555555555555"
                    }
                    """#
            ),
        ]
    )
    func invalidEnvelopeIsRejected(_ fixture: InvalidSessionEnvelopeFixture) throws(any Error) {
        let service = "com.mangalibrary.tests.session.\(UUID().uuidString)"
        let store = SessionKeychainStore(service: service, legacyServices: [])
        defer { try? store.removeAll() }
        try insertKeychainPayload(fixture.payload, service: service)

        #expect(throws: SessionStorageError.corruptSessionRecord) {
            try store.load()
        }
    }

    @Test("A legacy V2 dual envelope is removed instead of reinterpreted")
    func legacyV2EnvelopeIsRemovedByRestore() async throws(any Error) {
        let service = "com.mangalibrary.tests.session.current.\(UUID().uuidString)"
        let legacyService = "com.mangalibrary.tests.session.v2.\(UUID().uuidString)"
        let store = SessionKeychainStore(service: service, legacyServices: [legacyService])
        defer { try? store.removeAll() }
        let payload = Data(
            #"""
            {
              "accessExpiresAt": 700003600,
              "accessToken": "synthetic-access",
              "formatVersion": 2,
              "generation": "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
              "refreshExpiresAt": 702592000,
              "refreshToken": "synthetic-refresh",
              "userID": "11111111-2222-3333-4444-555555555555"
            }
            """#.utf8
        )
        try insertKeychainPayload(payload, service: legacyService)
        let persistence = SessionPersistenceActor(keychain: store)

        #expect(try await persistence.restore() == .signedOut)
        #expect(try keychainItemCount(service: service) == 0)
        #expect(try keychainItemCount(service: legacyService) == 0)
    }

    @Test("Restore removes a residual V2 envelope beside a valid V3 authority")
    func validV3RestoreRemovesResidualV2Envelope() async throws(any Error) {
        let service = "com.mangalibrary.tests.session.current.\(UUID().uuidString)"
        let legacyService = "com.mangalibrary.tests.session.v2.\(UUID().uuidString)"
        let store = SessionKeychainStore(service: service, legacyServices: [legacyService])
        defer { try? store.removeAll() }
        let session = try makeSession(userID: Self.userA, generation: Self.generationA)
        try store.save(session)
        try insertKeychainPayload(Data("legacy-v2-envelope".utf8), service: legacyService)
        let persistence = SessionPersistenceActor(keychain: store)

        #expect(try await persistence.restore() == .active(session))
        #expect(try keychainItemCount(service: service) == 1)
        #expect(try keychainItemCount(service: legacyService) == 0)
    }

    @Test("Logout cleanup removes current and legacy session namespaces")
    func removeAllDeletesCurrentAndLegacyItems() throws(any Error) {
        let currentService = "com.mangalibrary.tests.session.current.\(UUID().uuidString)"
        let legacyService = "com.mangalibrary.tests.session.legacy.\(UUID().uuidString)"
        let store = SessionKeychainStore(service: currentService, legacyServices: [legacyService])
        defer { try? store.removeAll() }
        try store.save(makeSession(userID: Self.userA, generation: Self.generationA))
        try insertKeychainPayload(Data("legacy".utf8), service: legacyService, account: "legacy-generation")

        try store.removeAll()

        #expect(try store.load() == nil)
        #expect(try keychainItemCount(service: currentService) == 0)
        #expect(try keychainItemCount(service: legacyService) == 0)
    }

    private func makeSession(
        userID: UUID,
        generation: UUID,
        accessValue: String = "synthetic-access-a"
    ) throws(SessionStorageError) -> SessionPersistedSession {
        try SessionPersistedSession(
            userID: userID,
            generation: generation,
            access: SessionCredential(value: accessValue, expiresAt: Self.issuedAt.addingTimeInterval(86_400))
        )
    }

    private func keychainAttributes(service: String) throws(any Error) -> [String: Any] {
        var query = currentItemQuery(service: service)
        query[kSecReturnAttributes] = true
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        try #require(status == errSecSuccess)
        return try #require(result as? [String: Any])
    }

    private func keychainItemCount(service: String) throws(any Error) -> Int {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrSynchronizable: kSecAttrSynchronizableAny,
            kSecReturnAttributes: true,
            kSecMatchLimit: kSecMatchLimitAll,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return 0 }

        try #require(status == errSecSuccess)
        return try #require(result as? [[String: Any]]).count
    }

    private func insertKeychainPayload(
        _ payload: Data,
        service: String,
        account: String = SessionKeychainStore.account
    ) throws(any Error) {
        let attributes: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable: false,
            kSecValueData: payload,
        ]
        try #require(SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess)
    }

    private func currentItemQuery(service: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: SessionKeychainStore.account,
            kSecAttrSynchronizable: false,
        ]
    }

    private static let issuedAt = Date(timeIntervalSince1970: 1_700_000_000)
    private static let userA = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    private static let userB = UUID(uuidString: "66666666-7777-8888-9999-AAAAAAAAAAAA")!
    private static let generationA = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
    private static let generationB = UUID(uuidString: "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF")!
}

struct InvalidSessionEnvelopeFixture: CustomTestStringConvertible {
    let testDescription: String
    let payload: Data
}

extension InvalidSessionEnvelopeFixture {
    init(_ testDescription: String, json: String) {
        self.testDescription = testDescription
        payload = Data(json.utf8)
    }
}
