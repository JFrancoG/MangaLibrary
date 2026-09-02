//
//  CollectionAccessTests.swift
//  MangaLibraryTests
//

import Foundation
import SwiftData
import Testing
@testable import MangaLibrary

@MainActor
@Suite("Collection access", .tags(.fast))
struct CollectionAccessTests {
    @Test("Reauthentication retains the known identity without authorizing mutations")
    func reauthenticationRetainsReadOnlyScope() {
        let access = AccountModel.State.authenticating(previousUserID: Self.userA).collectionAccess

        #expect(access == .user(Self.userA, restriction: .authenticating))
        #expect(access.userID == Self.userA)
        #expect(access.canMutate == false)
    }

    @Test("A confirmed identity change replaces the collection scope")
    func authenticatedIdentityOwnsTheScope() {
        let accessA = AccountModel.State.authenticated(Self.accountA, notice: nil).collectionAccess
        let accessB = AccountModel.State.authenticated(Self.accountB, notice: nil).collectionAccess

        #expect(accessA == .user(Self.userA, restriction: nil))
        #expect(accessB == .user(Self.userB, restriction: nil))
        #expect(accessA.userID != accessB.userID)
    }

    @Test("Authentication required and signing out preserve only read access")
    func transitionalStatesBlockMutations() {
        let authenticationRequired = AccountModel.State.authenticationRequired(userID: Self.userA, failure: nil)
        let signingOut = AccountModel.State.signingOut(Self.accountA)

        #expect(authenticationRequired.collectionAccess == .user(Self.userA, restriction: .authenticationRequired))
        #expect(signingOut.collectionAccess == .user(Self.userA, restriction: .signingOut))
        #expect(authenticationRequired.collectionAccess.canMutate == false)
        #expect(signingOut.collectionAccess.canMutate == false)
    }

    @Test("States without a known identity cannot resolve collection data")
    func identityFreeStatesRemainUnavailable() {
        #expect(AccountModel.State.restoring.collectionAccess == .unavailable(.restoring))
        #expect(
            AccountModel.State.restorationFailed(failure: .unavailable).collectionAccess
                == .unavailable(.restorationFailed)
        )
        #expect(AccountModel.State.signedOut(failure: nil).collectionAccess == .unavailable(.signedOut))
        #expect(
            AccountModel.State.authenticating(previousUserID: nil).collectionAccess
                == .unavailable(.authenticating)
        )
    }

    fileprivate static let userA = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    private static let userB = UUID(uuidString: "66666666-7777-8888-9999-AAAAAAAAAAAA")!
    fileprivate static let accountA = SessionAccount(
        id: userA,
        email: "reader-a@example.invalid",
        isActive: true,
        isAdmin: false,
        role: "user"
    )
    private static let accountB = SessionAccount(
        id: userB,
        email: "reader-b@example.invalid",
        isActive: true,
        isAdmin: false,
        role: "user"
    )
}

@MainActor
@Suite("Collection mutation authorization", .tags(.integration))
struct CollectionMutationAuthorizationTests {
    @Test("Only the matching authenticated account can create queued work")
    func matchingAuthenticatedAccountMutates() async throws {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let accountModel = AccountPreviewSupport.model(state: .authenticated(Self.accountA, notice: nil))
        let mutation = CollectionMutation(
            actor: CollectionMutationActor(modelContainer: container),
            accountModel: accountModel,
            sessionAuthorization: .deterministic
        )

        _ = try await mutation(Self.command)

        let context = ModelContext(container)
        #expect(try context.fetchCount(FetchDescriptor<CollectionEntry>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<CollectionOutboxOperation>()) == 1)
    }

    @Test(
        "A stale submit cannot mutate without the matching authenticated account",
        arguments: CollectionAuthorizationDenial.allCases
    )
    func staleSubmitIsRejected(_ denial: CollectionAuthorizationDenial) async throws {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let accountModel = AccountPreviewSupport.model(state: denial.state)
        let mutation = CollectionMutation(
            actor: CollectionMutationActor(modelContainer: container),
            accountModel: accountModel,
            sessionAuthorization: .deterministic
        )

        await #expect(throws: CollectionMutationError.authenticationRequired) {
            try await mutation(Self.command)
        }

        let context = ModelContext(container)
        #expect(try context.fetchCount(FetchDescriptor<CollectionEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<CollectionOutboxOperation>()) == 0)
    }

    @Test("Presentation authentication cannot bypass a rejected session generation")
    func sessionGenerationDenialPreventsMutation() async throws {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let accountModel = AccountPreviewSupport.model(state: .authenticated(Self.accountA, notice: nil))
        let mutation = CollectionMutation(
            actor: CollectionMutationActor(modelContainer: container),
            accountModel: accountModel,
            sessionAuthorization: .denied
        )

        await #expect(throws: CollectionMutationError.authenticationRequired) {
            try await mutation(Self.command)
        }

        let context = ModelContext(container)
        #expect(try context.fetchCount(FetchDescriptor<CollectionEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<CollectionOutboxOperation>()) == 0)
    }

    @Test("A local commit consumes authority again inside the SwiftData transaction")
    func invalidationBeforeLocalCommitPreventsMutation() async throws {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let authority = SessionAuthority(userID: Self.userA, generation: UUID())
        let commitGate = SessionCommitGate(activeAuthority: authority)
        let authorization = commitGate.authorization(for: authority)
        commitGate.invalidate(authority)
        let actor = CollectionMutationActor(modelContainer: container)

        await #expect(throws: CollectionMutationError.authenticationRequired) {
            try await actor.apply(Self.command, authorization: authorization)
        }

        let context = ModelContext(container)
        #expect(try context.fetchCount(FetchDescriptor<CollectionEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<CollectionOutboxOperation>()) == 0)
    }

    private static let command = CollectionMutationCommand(
        userID: Self.userA,
        mangaID: 42,
        mangaSnapshot: CollectionMangaSnapshot(manga: Self.manga),
        knownTotalVolumes: Self.manga.totalVolumes,
        change: .replaceState(ownedVolumes: [1, 3], readingVolume: 2, isComplete: false)
    )
    private static let manga = Manga(
        id: 42,
        title: "Manga A",
        titleEnglish: nil,
        titleJapanese: nil,
        synopsis: nil,
        score: 8,
        status: .finished,
        authors: [],
        demographics: [],
        genres: [],
        themes: [],
        totalVolumes: 3,
        coverURL: nil
    )
    fileprivate static let userA = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    private static let userB = UUID(uuidString: "66666666-7777-8888-9999-AAAAAAAAAAAA")!
    fileprivate static let accountA = SessionAccount(
        id: userA,
        email: "reader-a@example.invalid",
        isActive: true,
        isAdmin: false,
        role: "user"
    )
    fileprivate static let accountB = SessionAccount(
        id: userB,
        email: "reader-b@example.invalid",
        isActive: true,
        isAdmin: false,
        role: "user"
    )
}

enum CollectionAuthorizationDenial: CaseIterable, CustomTestStringConvertible {
    case authenticationRequired
    case authenticatingKnownUser
    case signingOut
    case anotherUser
    case restoring
    case restorationFailed
    case signedOut
    case authenticatingWithoutIdentity

    @MainActor
    var state: AccountModel.State {
        switch self {
        case .authenticationRequired:
            .authenticationRequired(userID: CollectionMutationAuthorizationTests.userA, failure: nil)
        case .authenticatingKnownUser:
            .authenticating(previousUserID: CollectionMutationAuthorizationTests.userA)
        case .signingOut:
            .signingOut(CollectionMutationAuthorizationTests.accountA)
        case .anotherUser:
            .authenticated(CollectionMutationAuthorizationTests.accountB, notice: nil)
        case .restoring:
            .restoring
        case .restorationFailed:
            .restorationFailed(failure: .unavailable)
        case .signedOut:
            .signedOut(failure: nil)
        case .authenticatingWithoutIdentity:
            .authenticating(previousUserID: nil)
        }
    }

    var testDescription: String {
        switch self {
        case .authenticationRequired: "authentication required"
        case .authenticatingKnownUser: "authenticating a known user"
        case .signingOut: "signing out"
        case .anotherUser: "another user"
        case .restoring: "restoring without identity"
        case .restorationFailed: "failed restoration without identity"
        case .signedOut: "signed out"
        case .authenticatingWithoutIdentity: "authenticating without identity"
        }
    }
}
