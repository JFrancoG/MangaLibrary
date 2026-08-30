//
//  SessionPersistenceStoreTests.swift
//  MangaLibraryTests
//

import Foundation
import Security
import Testing
@testable import MangaLibrary

private enum SessionPersistenceTestRuntime {
    #if targetEnvironment(simulator)
    static let supportsCompleteFileProtection = false
    #else
    static let supportsCompleteFileProtection = true
    #endif
}

@Suite("Session persistence stores", .tags(.integration))
struct SessionPersistenceStoreTests {
    @Test("Keychain keeps one versioned bundle scoped to its opaque generation")
    func keychainRoundTripIsGenerationScoped() throws(any Error) {
        let service = "com.mangalibrary.tests.session.\(UUID().uuidString)"
        let store = SessionKeychainStore(service: service)
        defer { try? store.removeAll() }

        let generation = UUID()
        let unrelatedGeneration = UUID()
        let original = try makeBundle(
            generation: generation,
            accessValue: "synthetic-access-a"
        )

        try store.save(original)

        let attributes = try keychainAttributes(
            service: service,
            generation: generation
        )
        #expect(attributes[kSecAttrService as String] as? String == service)
        #expect(
            attributes[kSecAttrAccount as String] as? String
                == generation.uuidString.lowercased()
        )
        #expect(
            attributes[kSecAttrAccessible as String] as? String
                == kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String
        )
        let storedData = try #require(
            attributes[kSecValueData as String] as? Data
        )
        let storedJSON = try #require(
            String(data: storedData, encoding: .utf8)
        )
        #expect(storedJSON.contains("\"use\"") == false)
        #expect(storedJSON.contains("userID") == false)
        #expect(storedJSON.contains("email") == false)
        #expect(try store.load(generation: generation) == original)
        #expect(try store.load(generation: unrelatedGeneration) == nil)

        let renewed = try makeBundle(
            generation: generation,
            accessValue: "synthetic-access-b"
        )
        try store.save(renewed)
        try store.remove(generation: unrelatedGeneration)

        #expect(try store.load(generation: generation) == renewed)

        try store.remove(generation: generation)
        #expect(try store.load(generation: generation) == nil)
    }

    @Test(
        "Invalid Keychain envelopes cannot become a session bundle",
        arguments: [
            InvalidSecretEnvelopeFixture(
                "missing allowlisted fields",
                json: #"{"formatVersion":1}"#
            ),
            InvalidSecretEnvelopeFixture(
                "generation differs from the opaque account",
                json: #"""
                    {
                      "accessExpiresAt": 700003600,
                      "accessToken": "synthetic-access",
                      "formatVersion": 1,
                      "generation": "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF",
                      "refreshExpiresAt": 702592000,
                      "refreshToken": "synthetic-refresh"
                    }
                    """#
            ),
        ]
    )
    func invalidSecretEnvelopeIsRejected(_ fixture: InvalidSecretEnvelopeFixture) throws(any Error) {
        let service = "com.mangalibrary.tests.session.\(UUID().uuidString)"
        let store = SessionKeychainStore(service: service)
        defer { try? store.removeAll() }
        let generation = UUID(
            uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
        )!
        try insertKeychainPayload(
            fixture.payload,
            service: service,
            generation: generation
        )

        #expect(throws: SessionStorageError.corruptSecretBundle) {
            try store.load(generation: generation)
        }
    }

    @Test("Ledger replacement keeps non-secret authority outside backup")
    func ledgerReplacementKeepsNonSecretAuthorityOutsideBackup() throws(any Error) {
        let directory = FileManager.default.temporaryDirectory
            .appending(component: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appending(component: "session-ledger.json")
        let store = SessionLedgerStore(fileURL: fileURL)
        let record = SessionLedgerRecord.active(
            userID: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            generation: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            revision: 7
        )

        try store.write(record)

        #expect(try store.read() == record)
        try expectBackupExclusion(at: directory)
        try expectBackupExclusion(at: fileURL)

        let rawData = try Data(contentsOf: fileURL)
        let rawJSON = try #require(String(data: rawData, encoding: .utf8))
        #expect(rawJSON.contains("11111111-2222-3333-4444-555555555555"))
        #expect(rawJSON.contains("AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"))
        #expect(rawJSON.contains("synthetic-access") == false)
        #expect(rawJSON.contains("synthetic-refresh") == false)
        #expect(rawJSON.contains("example.invalid") == false)

        try setBackupExclusion(
            at: directory,
            isExcludedFromBackup: false
        )
        try setBackupExclusion(
            at: fileURL,
            isExcludedFromBackup: false
        )
        try store.write(
            .logoutPrepared(
                userID: record.userID,
                generation: try #require(record.sessionGeneration),
                revision: record.revision + 1
            )
        )
        #expect(try store.read()?.phase == .logoutPrepared)
        try expectBackupExclusion(at: directory)
        try expectBackupExclusion(at: fileURL)
    }

    @Test(
        "Ledger replacement restores complete file protection",
        .enabled(
            if: SessionPersistenceTestRuntime.supportsCompleteFileProtection,
            "Requires a physical iOS device"
        )
    )
    func ledgerReplacementRestoresCompleteFileProtection() throws(any Error) {
        let directory = FileManager.default.temporaryDirectory
            .appending(component: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appending(component: "session-ledger.json")
        let store = SessionLedgerStore(fileURL: fileURL)
        let record = SessionLedgerRecord.active(
            userID: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            generation: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            revision: 7
        )

        try store.write(record)
        try expectCompleteProtection(at: directory)
        try expectCompleteProtection(at: fileURL)

        try setFileProtection(at: directory, protection: .none)
        try setFileProtection(at: fileURL, protection: .none)
        try store.write(
            .logoutPrepared(
                userID: record.userID,
                generation: try #require(record.sessionGeneration),
                revision: record.revision + 1
            )
        )

        try expectCompleteProtection(at: directory)
        try expectCompleteProtection(at: fileURL)
    }

    @Test("A corrupt ledger is rejected instead of becoming authority")
    func corruptLedgerIsRejected() throws(any Error) {
        let directory = FileManager.default.temporaryDirectory
            .appending(component: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let fileURL = directory.appending(component: "session-ledger.json")
        try Data(#"{"formatVersion":99}"#.utf8).write(to: fileURL)
        let store = SessionLedgerStore(fileURL: fileURL)

        #expect(throws: SessionStorageError.corruptLedger) {
            try store.read()
        }
    }

    @Test("An unavailable protected ledger preserves its recovery staging")
    func unavailableProtectedLedgerDoesNotRemoveStaging() throws(any Error) {
        let directory = FileManager.default.temporaryDirectory
            .appending(component: UUID().uuidString, directoryHint: .isDirectory)
        let fileURL = directory.appending(component: "session-ledger.json")
        let stagingURL = directory.appending(
            component: ".session-ledger-staging-v1.json"
        )
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: fileURL.path()
            )
            try? FileManager.default.removeItem(at: directory)
        }
        let store = SessionLedgerStore(fileURL: fileURL)
        try store.write(
            .active(
                userID: UUID(
                    uuidString: "11111111-2222-3333-4444-555555555555"
                )!,
                generation: UUID(
                    uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
                )!,
                revision: 7
            )
        )
        let stagingData = Data("orphan-staging".utf8)
        try stagingData.write(to: stagingURL, options: [.completeFileProtection])
        try FileManager.default.setAttributes(
            [.posixPermissions: 0],
            ofItemAtPath: fileURL.path()
        )

        #expect(throws: SessionStorageError.temporarilyUnavailable) {
            try store.read()
        }
        #expect(try Data(contentsOf: stagingURL) == stagingData)
    }

    @Test("An interrupted staging file is removed and never gains authority")
    func orphanStagingIsRemovedBeforeRestore() throws(any Error) {
        let directory = FileManager.default.temporaryDirectory
            .appending(component: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let fileURL = directory.appending(component: "session-ledger.json")
        let stagingURL = directory.appending(
            component: ".session-ledger-staging-v1.json"
        )
        try Data(
            #"{"formatVersion":1,"userID":"11111111-2222-3333-4444-555555555555"}"#.utf8
        ).write(to: stagingURL)
        let store = SessionLedgerStore(fileURL: fileURL)

        #expect(try store.read() == nil)
        #expect(
            FileManager.default.fileExists(atPath: stagingURL.path()) == false
        )
    }

    private func makeBundle(generation: UUID, accessValue: String) throws(SessionStorageError) -> SessionSecretBundle {
        let issuedAt = Date(timeIntervalSince1970: 1_700_000_000)
        return try SessionSecretBundle(
            generation: generation,
            access: SessionCredential(
                value: accessValue,
                use: .access,
                expiresAt: issuedAt.addingTimeInterval(3_600)
            ),
            refresh: SessionCredential(
                value: "synthetic-refresh",
                use: .refresh,
                expiresAt: issuedAt.addingTimeInterval(2_592_000)
            )
        )
    }

    private func keychainAttributes(service: String, generation: UUID) throws(any Error) -> [String: Any] {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: generation.uuidString.lowercased(),
            kSecAttrSynchronizable: false,
            kSecReturnAttributes: true,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        #expect(status == errSecSuccess)
        return try #require(result as? [String: Any])
    }

    private func insertKeychainPayload(_ payload: Data, service: String, generation: UUID) throws(any Error) {
        let attributes: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: generation.uuidString.lowercased(),
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable: false,
            kSecValueData: payload,
        ]
        let status = SecItemAdd(attributes as CFDictionary, nil)
        try #require(status == errSecSuccess)
    }

    private func expectBackupExclusion(at url: URL) throws(any Error) {
        let resourceValues = try url.resourceValues(
            forKeys: [.isExcludedFromBackupKey]
        )
        #expect(resourceValues.isExcludedFromBackup == true)
    }

    private func expectCompleteProtection(at url: URL) throws(any Error) {
        let resourceValues = try url.resourceValues(
            forKeys: [.fileProtectionKey]
        )
        #expect(resourceValues.fileProtection == .complete)
    }

    private func setFileProtection(
        at url: URL,
        protection: FileProtectionType
    ) throws(any Error) {
        try FileManager.default.setAttributes(
            [.protectionKey: protection],
            ofItemAtPath: url.path()
        )
    }

    private func setBackupExclusion(
        at url: URL,
        isExcludedFromBackup: Bool
    ) throws(any Error) {
        var values = URLResourceValues()
        values.isExcludedFromBackup = isExcludedFromBackup
        var mutableURL = url
        try mutableURL.setResourceValues(values)
    }
}

struct InvalidSecretEnvelopeFixture:
    Sendable,
    CustomTestStringConvertible
{
    let testDescription: String
    let payload: Data

}

extension InvalidSecretEnvelopeFixture {
    init(_ testDescription: String, json: String) {
        self.testDescription = testDescription
        payload = Data(json.utf8)
    }
}
