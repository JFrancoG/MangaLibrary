//
//  CollectionAccessTests.swift
//  MangaLibraryTests
//

import Foundation
import SwiftData
import Synchronization
import Testing
@testable import MangaLibrary

@Suite("Collection access", .tags(.fast))
struct CollectionAccessTests {
    @Test("Reauthentication retains the known identity without authorizing mutations")
    func reauthenticationRetainsReadOnlyScope() {
        let access = AccountModel.State.authenticating(previousUserID: Self.userA).collectionAccess

        #expect(access == .user(CollectionUserScope(userID: Self.userA, authority: nil), restriction: .authenticating))
        #expect(access.userID == Self.userA)
        #expect(access.canMutate == false)
    }

    @Test("A confirmed identity change replaces the collection scope")
    func authenticatedIdentityOwnsTheScope() {
        let accessA = AccountModel.State.authenticated(Self.accountA, notice: nil).collectionAccess
        let accessB = AccountModel.State.authenticated(Self.accountB, notice: nil).collectionAccess

        #expect(
            accessA == .user(
                CollectionUserScope(userID: Self.userA, authority: Self.accountA.authority),
                restriction: nil
            )
        )
        #expect(
            accessB == .user(
                CollectionUserScope(userID: Self.userB, authority: Self.accountB.authority),
                restriction: nil
            )
        )
        #expect(accessA.userID != accessB.userID)
    }

    @Test("Authentication required and signing out preserve only read access")
    func transitionalStatesBlockMutations() {
        let authenticationRequired = AccountModel.State.authenticationRequired(userID: Self.userA, failure: nil)
        let signingOut = AccountModel.State.signingOut(Self.accountA)

        #expect(
            authenticationRequired.collectionAccess == .user(
                CollectionUserScope(userID: Self.userA, authority: nil),
                restriction: .authenticationRequired
            )
        )
        #expect(
            signingOut.collectionAccess == .user(
                CollectionUserScope(userID: Self.userA, authority: Self.accountA.authority),
                restriction: .signingOut
            )
        )
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
        authority: SessionAuthority(
            userID: userA,
            generation: UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!
        ),
        id: userA,
        email: "reader-a@example.invalid",
        isActive: true,
        isAdmin: false,
        role: "user"
    )
    private static let accountB = SessionAccount(
        authority: SessionAuthority(
            userID: userB,
            generation: UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000002")!
        ),
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

    @Test("A rejected session generation reconciles Account before denying a mutation")
    func sessionGenerationDenialReconcilesPresentation() async throws {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let userID = Self.userA
        let accountModel = AccountModel(
            initialState: .authenticated(Self.accountA, notice: nil),
            operations: AccountModel.Operations(
                currentSnapshot: { .authenticationRequired(userID) },
                restore: { .notRestored },
                login: { _, _ in .notRestored },
                register: { _, _ in .notSubmitted(.unavailable) },
                logout: { _ in .notRestored }
            )
        )
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
        #expect(accountModel.state == .authenticationRequired(userID: Self.userA, failure: .authenticationRequired))
        #expect(accountModel.state.collectionAccess.canMutate == false)
    }

    @Test("A local commit consumes authority again inside the SwiftData transaction")
    func invalidationBeforeLocalCommitPreventsMutation() async throws {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let authority = Self.accountA.authority
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

    @Test("A stale editor cannot submit into a newer generation of the same account")
    func staleEditorRejectsSameUserReplacementBeforeResolvingAuthorization() async throws(any Error) {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let calls = Mutex(0)
        let accountModel = AccountPreviewSupport.model(state: .authenticated(Self.replacementAccountA, notice: nil))
        let mutation = CollectionMutation(
            actor: CollectionMutationActor(modelContainer: container),
            accountModel: accountModel,
            sessionAuthorization: CollectionSessionAuthorization { authority in
                calls.withLock {
                    $0 += 1
                }
                return SessionCommitGate(activeAuthority: authority).authorization(for: authority)
            }
        )

        await #expect(throws: CollectionMutationError.authenticationRequired) {
            try await mutation(Self.command)
        }

        try expectEmptyCollection(in: container)
        #expect(calls.withLock { $0 } == 0)
        #expect(accountModel.state == .authenticated(Self.replacementAccountA, notice: nil))
    }

    @Test("The model actor rejects a capability from another generation of the same account")
    func modelActorRejectsSameUserReplacementCapability() async throws(any Error) {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let gate = SessionCommitGate(activeAuthority: Self.replacementAccountA.authority)
        let authorization = gate.authorization(for: Self.replacementAccountA.authority)
        let actor = CollectionMutationActor(modelContainer: container)

        await #expect(throws: CollectionMutationError.authenticationRequired) {
            try await actor.apply(Self.command, authorization: authorization)
        }

        try expectEmptyCollection(in: container)
    }

    @Test("A second-fence rejection also reconciles Account presentation")
    func commitGateDenialReconcilesPresentation() async throws(any Error) {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let authority = Self.accountA.authority
        let gate = SessionCommitGate(activeAuthority: authority)
        let authorization = gate.authorization(for: authority)
        gate.invalidate(authority)
        let calls = Mutex(0)
        let accountModel = accountModelWithAuthenticationRequiredSnapshot()
        let mutation = CollectionMutation(
            actor: CollectionMutationActor(modelContainer: container),
            accountModel: accountModel,
            sessionAuthorization: CollectionSessionAuthorization { _ in
                calls.withLock { count in
                    count += 1
                    return count == 1 ? authorization : nil
                }
            }
        )

        await #expect(throws: CollectionMutationError.authenticationRequired) {
            try await mutation(Self.command)
        }

        try expectEmptyCollection(in: container)
        #expect(calls.withLock { $0 } == 2)
        #expect(accountModel.state == .authenticationRequired(userID: Self.userA, failure: .authenticationRequired))
        #expect(accountModel.state.collectionAccess.canMutate == false)
    }

    @Test("A same-generation JWT replacement retries the uncommitted mutation once")
    func credentialReplacementRetriesMutationWithCurrentCapability() async throws(any Error) {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let authority = Self.accountA.authority
        let gate = SessionCommitGate(activeAuthority: authority)
        let stale = gate.authorization(for: authority)
        gate.activate(authority)
        let current = gate.authorization(for: authority)
        let authorizations = CollectionCommitAuthorizationSequence([stale, current])
        let accountModel = AccountPreviewSupport.model(state: .authenticated(Self.accountA, notice: nil))
        let mutation = CollectionMutation(
            actor: CollectionMutationActor(modelContainer: container),
            accountModel: accountModel,
            sessionAuthorization: CollectionSessionAuthorization { _ in
                authorizations.next()
            }
        )

        let result = try await mutation(Self.command)

        let context = ModelContext(container)
        let consumedEveryAuthorization = authorizations.isEmpty
        #expect(result.userID == Self.userA)
        #expect(try context.fetchCount(FetchDescriptor<CollectionEntry>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<CollectionOutboxOperation>()) == 1)
        #expect(consumedEveryAuthorization)
        #expect(accountModel.state == .authenticated(Self.accountA, notice: nil))
    }

    @Test("A different session generation cannot retry an uncommitted mutation")
    func generationReplacementStillPreventsMutation() async throws(any Error) {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let authorityA = Self.accountA.authority
        let authorityB = SessionAuthority(userID: Self.userA, generation: UUID())
        let gateA = SessionCommitGate(activeAuthority: authorityA)
        let stale = gateA.authorization(for: authorityA)
        gateA.invalidate(authorityA)
        let gateB = SessionCommitGate(activeAuthority: authorityB)
        let current = gateB.authorization(for: authorityB)
        let authorizations = CollectionCommitAuthorizationSequence([stale, current])
        let accountModel = AccountPreviewSupport.model(state: .authenticated(Self.accountA, notice: nil))
        let mutation = CollectionMutation(
            actor: CollectionMutationActor(modelContainer: container),
            accountModel: accountModel,
            sessionAuthorization: CollectionSessionAuthorization { _ in
                authorizations.next()
            }
        )

        await #expect(throws: CollectionMutationError.persistenceConflict) {
            try await mutation(Self.command)
        }

        try expectEmptyCollection(in: container)
        let consumedEveryAuthorization = authorizations.isEmpty
        #expect(consumedEveryAuthorization)
        #expect(accountModel.state == .authenticated(Self.accountA, notice: nil))
    }

    @Test(
        "Cancellation while resolving local authorization never becomes reauthentication",
        arguments: CollectionAuthorizationCancellationStage.allCases
    )
    func authorizationCancellationRemainsCancellation(
        stage: CollectionAuthorizationCancellationStage
    ) async throws(any Error) {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let authority = Self.accountA.authority
        let gate = SessionCommitGate(activeAuthority: authority)
        let first = gate.authorization(for: authority)
        gate.activate(authority)
        let second = gate.authorization(for: authority)
        gate.activate(authority)
        let callCount = Mutex(0)
        let accountModel = AccountPreviewSupport.model(state: .authenticated(Self.accountA, notice: nil))
        let mutation = CollectionMutation(
            actor: CollectionMutationActor(modelContainer: container),
            accountModel: accountModel,
            sessionAuthorization: CollectionSessionAuthorization { _ in
                try callCount.withLock { count in
                    count += 1
                    if count == stage.rawValue {
                        throw CancellationError()
                    }
                    return count == 1 ? first : second
                }
            }
        )

        await #expect(throws: CollectionMutationError.cancelled) {
            try await mutation(Self.command)
        }

        try expectEmptyCollection(in: container)
        #expect(callCount.withLock { $0 } == stage.rawValue)
        #expect(accountModel.state == .authenticated(Self.accountA, notice: nil))
    }

    @Test("A commit capability expiring after resolution blocks mutation and reconciles Account")
    func commitCapabilityExpirationReconcilesPresentation() async throws(any Error) {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let authority = Self.accountA.authority
        let clock = Mutex(Self.now)
        let gate = SessionCommitGate(
            activeAuthority: authority,
            expiresAt: Self.now.addingTimeInterval(1),
            now: { clock.withLock { $0 } }
        )
        let authorization = gate.authorization(for: authority)
        let calls = Mutex(0)
        let accountModel = accountModelWithAuthenticationRequiredSnapshot()
        let mutation = CollectionMutation(
            actor: CollectionMutationActor(modelContainer: container),
            accountModel: accountModel,
            sessionAuthorization: CollectionSessionAuthorization { _ in
                calls.withLock { count in
                    count += 1
                    if count == 1 {
                        clock.withLock {
                            $0 = $0.addingTimeInterval(2)
                        }
                        return authorization
                    }
                    return nil
                }
            }
        )

        await #expect(throws: CollectionMutationError.authenticationRequired) {
            try await mutation(Self.command)
        }

        try expectEmptyCollection(in: container)
        #expect(calls.withLock { $0 } == 2)
        #expect(accountModel.state == .authenticationRequired(userID: Self.userA, failure: .authenticationRequired))
        #expect(accountModel.state.collectionAccess.canMutate == false)
    }

    @Test("A failed expiry cleanup remains visible when local authorization is resolved")
    func authorizationCleanupFailureReconcilesPresentation() async throws(any Error) {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let accountModel = accountModelWithAuthenticationRequiredSnapshot()
        let mutation = CollectionMutation(
            actor: CollectionMutationActor(modelContainer: container),
            accountModel: accountModel,
            sessionAuthorization: CollectionSessionAuthorization { _ in
                throw SessionControllerError.persistenceUnavailable
            }
        )

        await #expect(throws: CollectionMutationError.authenticationRequired) {
            try await mutation(Self.command)
        }

        try expectEmptyCollection(in: container)
        #expect(accountModel.state == .authenticationRequired(userID: Self.userA, failure: .persistenceUnavailable))
        #expect(accountModel.state.collectionAccess.canMutate == false)
    }

    private func accountModelWithAuthenticationRequiredSnapshot() -> AccountModel {
        let userID = Self.userA
        return AccountModel(
            initialState: .authenticated(Self.accountA, notice: nil),
            operations: AccountModel.Operations(
                currentSnapshot: { .authenticationRequired(userID) },
                restore: { .notRestored },
                login: { _, _ in .notRestored },
                register: { _, _ in .notSubmitted(.unavailable) },
                logout: { _ in .notRestored }
            )
        )
    }

    private func expectEmptyCollection(in container: ModelContainer) throws(any Error) {
        let context = ModelContext(container)
        #expect(try context.fetchCount(FetchDescriptor<CollectionEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<CollectionOutboxOperation>()) == 0)
    }

    private static let command = CollectionMutationCommand(
        authority: Self.accountA.authority,
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
    private static let now = Date(timeIntervalSince1970: 1_700_000_000)
    private static let userB = UUID(uuidString: "66666666-7777-8888-9999-AAAAAAAAAAAA")!
    fileprivate static let accountA = SessionAccount(
        authority: SessionAuthority(
            userID: userA,
            generation: UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!
        ),
        id: userA,
        email: "reader-a@example.invalid",
        isActive: true,
        isAdmin: false,
        role: "user"
    )
    fileprivate static let accountB = SessionAccount(
        authority: SessionAuthority(
            userID: userB,
            generation: UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000002")!
        ),
        id: userB,
        email: "reader-b@example.invalid",
        isActive: true,
        isAdmin: false,
        role: "user"
    )
    private static let replacementAccountA = SessionAccount(
        authority: SessionAuthority(
            userID: userA,
            generation: UUID(uuidString: "CCCCCCCC-0000-0000-0000-000000000003")!
        ),
        id: userA,
        email: "reader-a@example.invalid",
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

enum CollectionAuthorizationCancellationStage: Int, CaseIterable, CustomTestStringConvertible {
    case initial = 1
    case replacement = 2
    case reconciliation = 3

    var testDescription: String {
        switch self {
        case .initial: "initial authorization"
        case .replacement: "replacement authorization"
        case .reconciliation: "final reconciliation"
        }
    }
}

private final class CollectionCommitAuthorizationSequence: Sendable {
    private let values: Mutex<[SessionCommitAuthorization]>

    init(_ values: [SessionCommitAuthorization]) {
        self.values = Mutex(values)
    }

    func next() -> SessionCommitAuthorization {
        values.withLock {
            $0.removeFirst()
        }
    }

    var isEmpty: Bool {
        values.withLock(\.isEmpty)
    }
}
