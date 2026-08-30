//
//  SessionPersistenceActorTests.swift
//  MangaLibraryTests
//

import Foundation
import Testing
@testable import MangaLibrary

@Suite("Session persistence actor", .tags(.integration))
struct SessionPersistenceActorTests {
    @Test("Activation publishes authority only after both stores agree")
    func activationRestoresTheCoherentGeneration() async throws(any Error) {
        let harness = makeHarness()
        defer { harness.cleanUp() }
        let bundle = try makeBundle(generation: Self.generationA)

        let activated = try await harness.persistence.activate(
            userID: Self.userA,
            generation: Self.generationA,
            access: bundle.access,
            refresh: bundle.refresh
        )

        #expect(
            activated.authority
                == SessionAuthority(
                    userID: Self.userA,
                    generation: Self.generationA,
                    revision: 1
                )
        )
        #expect(activated.bundle == bundle)
        #expect(try await harness.persistence.restore() == .active(activated))
    }

    @Test("A Keychain bundle without a ledger has no authority and is removed")
    func orphanBundleFailsClosed() async throws(any Error) {
        let harness = makeHarness()
        defer { harness.cleanUp() }
        try harness.keychain.save(try makeBundle(generation: Self.generationA))

        #expect(try await harness.persistence.restore() == .signedOut)
        #expect(try harness.keychain.load(generation: Self.generationA) == nil)
    }

    @Test("A missing active bundle preserves only the stable scope identity")
    func missingActiveBundleRequiresAuthentication() async throws(any Error) {
        let harness = makeHarness()
        defer { harness.cleanUp() }
        try harness.ledger.write(
            .active(
                userID: Self.userA,
                generation: Self.generationA,
                revision: 5
            )
        )

        #expect(
            try await harness.persistence.restore()
                == .authenticationRequired(Self.userA)
        )
        #expect(
            try harness.ledger.read()
                == .authenticationRequired(userID: Self.userA, revision: 7)
        )
    }

    @Test("Prepared logout survives relaunch and can still be cancelled")
    func preparedLogoutCanBeRestoredAndCancelled() async throws(any Error) {
        let harness = makeHarness()
        defer { harness.cleanUp() }
        let active = try await activateA(in: harness)
        let preparedAuthority = try #require(
            try await harness.persistence.prepareLogout(
                expected: active.authority
            )
        )

        let prepared = SessionPersistedSession(
            authority: preparedAuthority,
            bundle: active.bundle
        )
        #expect(
            try await harness.persistence.restore()
                == .logoutPrepared(prepared)
        )

        let cancelled = try #require(
            try await harness.persistence.cancelLogout(
                expected: preparedAuthority
            )
        )
        #expect(cancelled.authority.revision == 3)
        #expect(cancelled.bundle == active.bundle)
        #expect(try await harness.persistence.restore() == .active(cancelled))
    }

    @Test("Recovery completes signed-out cleanup after the point of no return")
    func signedOutCleanupPendingNeverReactivates() async throws(any Error) {
        let harness = makeHarness()
        defer { harness.cleanUp() }
        try harness.keychain.save(try makeBundle(generation: Self.generationA))
        try harness.ledger.write(
            .cleanupPending(
                userID: Self.userA,
                generation: Self.generationA,
                revision: 8,
                completion: .signedOut
            )
        )

        #expect(try await harness.persistence.restore() == .signedOut)
        #expect(try harness.ledger.read() == nil)
        #expect(try harness.keychain.load(generation: Self.generationA) == nil)
    }

    @Test("Relaunch finishes signed-out cleanup after its bundle was deleted")
    func signedOutRecoveryFinishesAfterTheDestructiveStep() async throws(any Error) {
        let harness = makeHarness()
        defer { harness.cleanUp() }
        let active = try await activateA(in: harness)
        let prepared = try #require(
            try await harness.persistence.prepareLogout(
                expected: active.authority
            )
        )
        let ticket = try #require(
            try await harness.persistence.invalidateLogout(expected: prepared)
        )

        try harness.keychain.remove(generation: ticket.generation)

        let relaunched = SessionPersistenceActor(
            keychain: harness.keychain,
            ledger: harness.ledger
        )
        #expect(try await relaunched.restore() == .signedOut)
        #expect(try harness.ledger.read() == nil)
        #expect(try harness.keychain.load(generation: ticket.generation) == nil)
    }

    @Test("Recovery completes authentication-required cleanup and keeps the UUID")
    func authenticationCleanupPendingKeepsOnlyTheUserID() async throws(any Error) {
        let harness = makeHarness()
        defer { harness.cleanUp() }
        try harness.keychain.save(try makeBundle(generation: Self.generationA))
        try harness.ledger.write(
            .cleanupPending(
                userID: Self.userA,
                generation: Self.generationA,
                revision: 8,
                completion: .authenticationRequired
            )
        )

        #expect(
            try await harness.persistence.restore()
                == .authenticationRequired(Self.userA)
        )
        #expect(
            try harness.ledger.read()
                == .authenticationRequired(userID: Self.userA, revision: 9)
        )
        #expect(try harness.keychain.load(generation: Self.generationA) == nil)
    }

    @Test("Relaunch finishes authentication cleanup after its bundle was deleted")
    func authenticationRecoveryFinishesAfterTheDestructiveStep() async throws(any Error) {
        let harness = makeHarness()
        defer { harness.cleanUp() }
        let active = try await activateA(in: harness)
        let ticket = try #require(
            try await harness.persistence.invalidateForAuthentication(
                expected: active.authority
            )
        )

        try harness.keychain.remove(generation: ticket.generation)

        let relaunched = SessionPersistenceActor(
            keychain: harness.keychain,
            ledger: harness.ledger
        )
        #expect(
            try await relaunched.restore()
                == .authenticationRequired(Self.userA)
        )
        #expect(
            try harness.ledger.read()
                == .authenticationRequired(
                    userID: Self.userA,
                    revision: 3
                )
        )
        #expect(try harness.keychain.load(generation: ticket.generation) == nil)
    }

    @Test("Access replacement keeps refresh and rejects a stale revision")
    func accessReplacementIsConditionalAndKeepsRefresh() async throws(any Error) {
        let harness = makeHarness()
        defer { harness.cleanUp() }
        let active = try await activateA(in: harness)
        let replacement = SessionCredential(
            value: "synthetic-access-b",
            use: .access,
            expiresAt: Self.issuedAt.addingTimeInterval(7_200)
        )

        let renewed = try #require(
            try await harness.persistence.replaceAccess(
                replacement,
                expected: active.authority
            )
        )
        #expect(renewed.bundle.access == replacement)
        #expect(renewed.bundle.refresh == active.bundle.refresh)

        let prepared = try #require(
            try await harness.persistence.prepareLogout(
                expected: active.authority
            )
        )
        #expect(
            try await harness.persistence.replaceAccess(
                SessionCredential(
                    value: "late-access-a",
                    use: .access,
                    expiresAt: Self.issuedAt.addingTimeInterval(8_000)
                ),
                expected: active.authority
            ) == nil
        )

        let cancelled = try #require(
            try await harness.persistence.cancelLogout(expected: prepared)
        )
        #expect(cancelled.bundle.access == replacement)
    }

    @Test("A permanent refresh rejection removes secrets but preserves scope")
    func permanentRefreshRejectionRequiresAuthentication() async throws(any Error) {
        let harness = makeHarness()
        defer { harness.cleanUp() }
        let active = try await activateA(in: harness)

        #expect(
            try await harness.persistence.markAuthenticationRequired(
                expected: active.authority
            )
        )
        #expect(
            try await harness.persistence.restore()
                == .authenticationRequired(Self.userA)
        )
        #expect(try harness.keychain.load(generation: Self.generationA) == nil)
    }

    @Test("A new generation stays blocked throughout an unfinished logout")
    func activationIsBlockedUntilLogoutCleanupFinishes() async throws(any Error) {
        let harness = makeHarness()
        defer { harness.cleanUp() }
        let sessionA = try await activateA(in: harness)
        let bundleB = try makeBundle(
            generation: Self.generationB,
            accessValue: "synthetic-access-session-b"
        )
        let preparedA = try #require(
            try await harness.persistence.prepareLogout(
                expected: sessionA.authority
            )
        )

        await #expect(throws: SessionPersistenceError.transitionBlocked) {
            try await harness.persistence.activate(
                userID: Self.userB,
                generation: Self.generationB,
                access: bundleB.access,
                refresh: bundleB.refresh
            )
        }

        _ = try #require(
            try await harness.persistence.invalidateLogout(expected: preparedA)
        )
        await #expect(throws: SessionPersistenceError.transitionBlocked) {
            try await harness.persistence.activate(
                userID: Self.userB,
                generation: Self.generationB,
                access: bundleB.access,
                refresh: bundleB.refresh
            )
        }

        #expect(
            try harness.ledger.read()
                == .cleanupPending(
                    userID: Self.userA,
                    generation: Self.generationA,
                    revision: 3,
                    completion: .signedOut
                )
        )
        #expect(
            try harness.keychain.load(generation: Self.generationA)?.access.value
                == "synthetic-access-a"
        )
        #expect(try harness.keychain.load(generation: Self.generationB) == nil)
    }

    @Test("A late effect from A cannot replace or delete session B")
    func staleGenerationCannotMutateANewerSession() async throws(any Error) {
        let harness = makeHarness()
        defer { harness.cleanUp() }
        let sessionA = try await activateA(in: harness)
        let preparedA = try #require(
            try await harness.persistence.prepareLogout(
                expected: sessionA.authority
            )
        )
        let cleanupA = try #require(
            try await harness.persistence.invalidateLogout(expected: preparedA)
        )
        #expect(
            try await harness.persistence.completeCleanup(expected: cleanupA)
                == .signedOut
        )

        let bundleB = try makeBundle(
            generation: Self.generationB,
            accessValue: "synthetic-access-session-b"
        )
        let sessionB = try await harness.persistence.activate(
            userID: Self.userB,
            generation: Self.generationB,
            access: bundleB.access,
            refresh: bundleB.refresh
        )

        #expect(
            try await harness.persistence.completeCleanup(expected: cleanupA)
                == nil
        )
        #expect(
            try await harness.persistence.prepareLogout(
                expected: sessionA.authority
            ) == nil
        )
        #expect(
            try await harness.persistence.markAuthenticationRequired(
                expected: sessionA.authority
            ) == false
        )
        #expect(try await harness.persistence.restore() == .active(sessionB))
    }

    @Test("A corrupt ledger removes every orphan instead of guessing authority")
    func corruptLedgerAndOrphanFailClosed() async throws(any Error) {
        let harness = makeHarness()
        defer { harness.cleanUp() }
        try harness.keychain.save(try makeBundle(generation: Self.generationA))
        try FileManager.default.createDirectory(
            at: harness.directory,
            withIntermediateDirectories: true
        )
        try Data(#"{"formatVersion":99}"#.utf8).write(
            to: harness.ledger.fileURL
        )

        #expect(try await harness.persistence.restore() == .signedOut)
        #expect(try harness.ledger.read() == nil)
        #expect(try harness.keychain.load(generation: Self.generationA) == nil)
    }

    private func activateA(in harness: SessionPersistenceHarness) async throws(any Error) -> SessionPersistedSession {
        let bundle = try makeBundle(generation: Self.generationA)
        return try await harness.persistence.activate(
            userID: Self.userA,
            generation: Self.generationA,
            access: bundle.access,
            refresh: bundle.refresh
        )
    }

    private func makeHarness() -> SessionPersistenceHarness {
        let directory = FileManager.default.temporaryDirectory
            .appending(component: UUID().uuidString, directoryHint: .isDirectory)
        let keychain = SessionKeychainStore(
            service: "com.mangalibrary.tests.persistence.\(UUID().uuidString)"
        )
        let ledger = SessionLedgerStore(
            fileURL: directory.appending(component: "session-ledger.json")
        )
        return SessionPersistenceHarness(
            directory: directory,
            keychain: keychain,
            ledger: ledger,
            persistence: SessionPersistenceActor(
                keychain: keychain,
                ledger: ledger
            )
        )
    }

    private func makeBundle(
        generation: UUID,
        accessValue: String = "synthetic-access-a"
    ) throws(SessionStorageError) -> SessionSecretBundle {
        try SessionSecretBundle(
            generation: generation,
            access: SessionCredential(
                value: accessValue,
                use: .access,
                expiresAt: Self.issuedAt.addingTimeInterval(3_600)
            ),
            refresh: SessionCredential(
                value: "synthetic-refresh",
                use: .refresh,
                expiresAt: Self.issuedAt.addingTimeInterval(2_592_000)
            )
        )
    }

    private static let issuedAt = Date(timeIntervalSince1970: 1_700_000_000)
    private static let userA = UUID(
        uuidString: "11111111-2222-3333-4444-555555555555"
    )!
    private static let userB = UUID(
        uuidString: "66666666-7777-8888-9999-AAAAAAAAAAAA"
    )!
    private static let generationA = UUID(
        uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
    )!
    private static let generationB = UUID(
        uuidString: "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF"
    )!
}

private struct SessionPersistenceHarness: Sendable {
    let directory: URL
    let keychain: SessionKeychainStore
    let ledger: SessionLedgerStore
    let persistence: SessionPersistenceActor

    func cleanUp() {
        try? keychain.removeAll()
        try? FileManager.default.removeItem(at: directory)
    }
}
