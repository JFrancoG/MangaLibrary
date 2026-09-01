//
//  SessionPersistenceActorTests.swift
//  MangaLibraryTests
//

import Foundation
import Testing
@testable import MangaLibrary

@Suite("Session persistence actor", .tags(.integration))
struct SessionPersistenceActorTests {
    @Test("Activation durably restores one complete session")
    func activationRestoresTheCurrentGeneration() async throws(any Error) {
        let harness = makeHarness()
        defer { harness.cleanUp() }

        let activated = try await activateA(in: harness.persistence)
        let relaunched = SessionPersistenceActor(keychain: harness.keychain)

        #expect(activated.authority == SessionAuthority(userID: Self.userA, generation: Self.generationA))
        #expect(try await relaunched.restore() == .active(activated))
    }

    @Test("Access replacement preserves refresh and requires the current generation")
    func accessReplacementIsConditional() async throws(any Error) {
        let harness = makeHarness()
        defer { harness.cleanUp() }
        let active = try await activateA(in: harness.persistence)
        let replacement = SessionCredential(
            value: "synthetic-access-renewed",
            use: .access,
            expiresAt: Self.issuedAt.addingTimeInterval(7_200)
        )

        let renewed = try #require(try await harness.persistence.replaceAccess(replacement, expected: active.authority))

        #expect(renewed.access == replacement)
        #expect(renewed.refresh == active.refresh)
        #expect(
            try await harness.persistence.replaceAccess(
                replacement,
                expected: SessionAuthority(userID: Self.userA, generation: Self.generationB)
            ) == nil
        )
    }

    @Test("A second activation stays blocked while a session exists")
    func activationRequiresAnEmptyAuthority() async throws(any Error) {
        let harness = makeHarness()
        defer { harness.cleanUp() }
        let sessionA = try await activateA(in: harness.persistence)
        let sessionB = try makeSession(userID: Self.userB, generation: Self.generationB)

        await #expect(throws: SessionPersistenceError.transitionBlocked) {
            try await harness.persistence.activate(
                userID: sessionB.userID,
                generation: sessionB.generation,
                access: sessionB.access,
                refresh: sessionB.refresh
            )
        }
        await #expect(throws: SessionPersistenceError.transitionBlocked) {
            try await harness.persistence.activate(
                userID: sessionB.userID,
                generation: sessionB.generation,
                access: sessionB.access,
                refresh: sessionB.refresh,
                replacing: SessionAuthority(userID: sessionA.userID, generation: Self.generationB)
            )
        }
    }

    @Test("A late generation cannot delete the current session")
    func staleGenerationCannotDeleteANewerSession() async throws(any Error) {
        let harness = makeHarness()
        defer { harness.cleanUp() }
        let sessionA = try await activateA(in: harness.persistence)
        #expect(try await harness.persistence.remove(expected: sessionA.authority))

        let candidateB = try makeSession(userID: Self.userB, generation: Self.generationB)
        let sessionB = try await harness.persistence.activate(
            userID: candidateB.userID,
            generation: candidateB.generation,
            access: candidateB.access,
            refresh: candidateB.refresh
        )

        #expect(try await harness.persistence.remove(expected: sessionA.authority) == false)
        #expect(try await harness.persistence.restore() == .active(sessionB))
    }

    private func activateA(in persistence: SessionPersistenceActor) async throws(any Error) -> SessionPersistedSession {
        let session = try makeSession(userID: Self.userA, generation: Self.generationA)
        return try await persistence.activate(
            userID: session.userID,
            generation: session.generation,
            access: session.access,
            refresh: session.refresh
        )
    }

    private func makeSession(userID: UUID, generation: UUID) throws(SessionStorageError) -> SessionPersistedSession {
        try SessionPersistedSession(
            userID: userID,
            generation: generation,
            access: SessionCredential(
                value: "synthetic-access",
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

    private func makeHarness() -> SessionPersistenceHarness {
        let keychain = SessionKeychainStore(
            service: "com.mangalibrary.tests.persistence.\(UUID().uuidString)",
            legacyServices: []
        )
        return SessionPersistenceHarness(keychain: keychain, persistence: SessionPersistenceActor(keychain: keychain))
    }

    private static let issuedAt = Date(timeIntervalSince1970: 1_700_000_000)
    private static let userA = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    private static let userB = UUID(uuidString: "66666666-7777-8888-9999-AAAAAAAAAAAA")!
    private static let generationA = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
    private static let generationB = UUID(uuidString: "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF")!
}

private struct SessionPersistenceHarness {
    let keychain: SessionKeychainStore
    let persistence: SessionPersistenceActor

    func cleanUp() {
        try? keychain.removeAll()
    }
}
