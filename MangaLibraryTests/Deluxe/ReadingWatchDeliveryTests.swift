import Foundation
import Synchronization
import Testing
@testable import MangaLibrary

@Suite("Canonical watch delivery", .tags(.integration))
struct ReadingWatchDeliveryTests {
    @Test(arguments: [RetirementFailure.manifest, .reload, .watch])
    func `retirement offers its verified redaction independently of manifest reload and transport failures`(
        failure: RetirementFailure
    ) async throws {
        let harness = Harness()
        let publisher = harness.publisher()
        try await harness.publish(using: publisher)
        let authorization = try #require(harness.gate.suspendForLogout(harness.authority))
        let commit = try await publisher.close(authorization: authorization)
        let fence = harness.files.withLock { $0[.fence] }
        let contexts = Mutex<[Data]>([])
        let reloads = Mutex(0)
        let retiring = harness.publisher(
            storage: ReadingSnapshotStorage(
                read: { file in harness.files.withLock { $0[file] } },
                replace: { file, data in
                    if file == .snapshot, failure == .manifest {
                        throw ReadingSnapshotStorageError.unavailable
                    }
                    harness.files.withLock {
                        $0[file] = data
                    }
                }
            ),
            requestReload: { _ in
                reloads.withLock {
                    $0 += 1
                }
                if failure == .reload {
                    throw ReadingSnapshotStorageError.unavailable
                }
            },
            sendWatchContext: { data in
                contexts.withLock {
                    $0.append(data)
                }
                if failure == .watch {
                    throw DeliveryError.notActivated
                }
            }
        )

        if failure == .manifest {
            await #expect(throws: ReadingSnapshotStorageError.unavailable) {
                try await retiring.finishRetirement(commit)
            }
        } else {
            try await retiring.finishRetirement(commit)
        }

        let delivered = try #require(contexts.withLock { $0.first })
        let redaction = try ReadingSnapshotCodec.decode(delivered)
        #expect(redaction.state == .redacted)
        #expect(redaction.sessionGeneration == harness.authority.generation)
        #expect(redaction.revision == 2)
        #expect(redaction.items.isEmpty)
        #expect(harness.files.withLock { $0[.fence] } == fence)
        let manifest = try #require(harness.files.withLock { $0[.snapshot] })
        #expect(try ReadingSnapshotCodec.decode(manifest).state == (failure == .manifest ? .content : .redacted))
        #expect(reloads.withLock { $0 } == (failure == .manifest ? 0 : 1))
    }

    enum RetirementFailure {
        case manifest, reload, watch
    }

    @Test(arguments: [false, true], [false, true])
    func `widget and watch delivery failures remain independent after a durable commit`(
        failReload: Bool,
        failWatch: Bool
    ) async throws {
        let harness = Harness()
        let reloads = Mutex(0)
        let contexts = Mutex<[Data]>([])
        let publisher = harness.publisher(
            requestReload: { _ in
                reloads.withLock {
                    $0 += 1
                }
                if failReload {
                    throw DeliveryError.notActivated
                }
            },
            sendWatchContext: { data in
                contexts.withLock {
                    $0.append(data)
                }
                if failWatch {
                    throw DeliveryError.notActivated
                }
            }
        )

        try await harness.publish(using: publisher)

        let delivered = try #require(contexts.withLock { $0.first })
        #expect(try ReadingSnapshotCodec.decode(delivered).items.map(\.mangaID) == [20, 10, 30])
        #expect(reloads.withLock { $0 } == 1)
        let manifest = try #require(harness.files.withLock { $0[.snapshot] })
        #expect(delivered == manifest)
        let recovered = harness.publisher(
            requestReload: { _ in
                reloads.withLock {
                    $0 += 1
                }
            },
            sendWatchContext: { data in
                contexts.withLock {
                    $0.append(data)
                }
            }
        )
        _ = try await recovered.recover()

        #expect(reloads.withLock { $0 } == (failReload ? 2 : 1))
        #expect(contexts.withLock { $0.count } == 1)
        #expect(harness.files.withLock { $0[.snapshot] } == manifest)
        try await recovered.deliverWatchContext(authorization: harness.authorization) { data in
            contexts.withLock {
                $0.append(data)
            }
        }
        #expect(contexts.withLock { $0.last } == manifest)
        #expect(contexts.withLock { $0.count } == 2)
    }

    @Test
    func `revocation after manifest commit still prevents automatic watch delivery`() async throws {
        let harness = Harness()
        let contexts = Mutex<[Data]>([])
        let publisher = harness.publisher(
            requestReload: { _ in
                harness.gate.invalidate(harness.authority)
            },
            sendWatchContext: { data in
                contexts.withLock {
                    $0.append(data)
                }
            }
        )

        try await harness.publish(using: publisher)

        let manifest = try #require(harness.files.withLock { $0[.snapshot] })
        #expect(try ReadingSnapshotCodec.decode(manifest).items.map(\.mangaID) == [20, 10, 30])
        #expect(contexts.withLock { $0.isEmpty })
    }

    @Test
    func `recovery sends only the reserved redaction when the manifest is still old content`() async throws {
        let harness = Harness()
        let publisher = harness.publisher()
        try await harness.publish(using: publisher)
        let closing = try #require(harness.gate.suspendForLogout(harness.authority))
        _ = try await publisher.close(authorization: closing)
        let before = harness.files.withLock { $0 }
        let contexts = Mutex<[Data]>([])
        let recovered = harness.publisher(sendWatchContext: { data in
            contexts.withLock {
                $0.append(data)
            }
        })

        #expect(try await recovered.recover() == .retirementPending(harness.authority.generation))

        let data = try #require(contexts.withLock { $0.first })
        let redaction = try ReadingSnapshotCodec.decode(data)
        #expect(redaction.state == .redacted)
        #expect(redaction.items.isEmpty)
        #expect(redaction.sessionGeneration == harness.authority.generation)
        #expect(redaction.revision == 2)
        #expect(harness.files.withLock { $0 } == before)
        #expect(harness.reloads.withLock { $0 } == 1)
    }

    @Test
    func `installing the companion replays persisted content without reserving or reloading`() async throws {
        let harness = Harness()
        let publisher = harness.publisher()
        try await harness.publish(using: publisher)
        let before = harness.files.withLock { $0 }
        let messages = Mutex<[Data]>([])

        try await harness.publisher().deliverWatchContext(authorization: harness.authorization) { data in
            messages.withLock { $0.append(data) }
        }

        let data = try #require(messages.withLock { $0.first })
        #expect(try ReadingSnapshotCodec.decode(data).items.map(\.mangaID) == [20, 10, 30])
        #expect(harness.files.withLock { $0 } == before)
        #expect(harness.reloads.withLock { $0 } == 1)
    }

    @Test
    func `closed fence replaces pending content with retirement before the manifest is redacted`() async throws {
        let harness = Harness()
        let publisher = harness.publisher()
        try await harness.publish(using: publisher)
        let closing = try #require(harness.gate.suspendForLogout(harness.authority))
        _ = try await publisher.close(authorization: closing)
        let messages = Mutex<[Data]>([])

        try await publisher.deliverWatchContext(authorization: nil) { data in
            messages.withLock { $0.append(data) }
        }

        let data = try #require(messages.withLock { $0.first })
        let delivered = try ReadingSnapshotCodec.decode(data)
        #expect(delivered.state == .redacted)
        #expect(delivered.sessionGeneration == harness.authority.generation)
        #expect(delivered.items.isEmpty)
        let manifest = try #require(harness.files.withLock { $0[.snapshot] })
        #expect(try ReadingSnapshotCodec.decode(manifest).state == .content)
    }

    @Test
    func `an open durable fence cannot substitute for a current session capability`() async throws {
        let harness = Harness()
        let publisher = harness.publisher()
        try await harness.publish(using: publisher)
        let messages = Mutex<[Data]>([])

        try await publisher.deliverWatchContext(authorization: harness.authorization) { data in
            messages.withLock { $0.append(data) }
        }
        try #require(messages.withLock { $0.count } == 1)
        messages.withLock { $0.removeAll() }

        try await publisher.deliverWatchContext(authorization: nil) { data in
            messages.withLock { $0.append(data) }
        }
        let oldAuthorization = harness.authorization
        _ = try #require(harness.gate.suspendForLogout(harness.authority))
        do {
            try await publisher.deliverWatchContext(authorization: oldAuthorization) { data in
                messages.withLock { $0.append(data) }
            }
        } catch is SessionCommitAuthorizationError {
        }

        #expect(messages.withLock { $0.isEmpty })
    }

    @Test
    func `a failed send retries the current redaction instead of its previous content`() async throws {
        let harness = Harness()
        let publisher = harness.publisher()
        try await harness.publish(using: publisher)
        await #expect(throws: DeliveryError.self) {
            try await publisher.deliverWatchContext(authorization: harness.authorization) { _ in
                throw DeliveryError.notActivated
            }
        }
        let closing = try #require(harness.gate.suspendForLogout(harness.authority))
        let commit = try await publisher.close(authorization: closing)
        try await publisher.finishRetirement(commit)
        let messages = Mutex<[Data]>([])

        try await harness.publisher().deliverWatchContext(authorization: nil) { data in
            messages.withLock { $0.append(data) }
        }

        let data = try #require(messages.withLock { $0.first })
        #expect(try ReadingSnapshotCodec.decode(data).state == .redacted)
    }

    private enum DeliveryError: Error { case notActivated }

    private final class Harness: Sendable {
        let files = Mutex<[ReadingSnapshotStorage.File: Data]>([:])
        let reloads = Mutex(0)
        let authority = SessionAuthority(
            userID: UUID(uuidString: "BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB")!,
            generation: UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA")!
        )
        let gate: SessionCommitGate

        var authorization: SessionCommitAuthorization { gate.authorization(for: authority) }

        init() {
            gate = SessionCommitGate(activeAuthority: authority)
        }

        func publisher(
            storage: ReadingSnapshotStorage? = nil,
            requestReload: (@Sendable (Data) throws -> Void)? = nil,
            sendWatchContext: @escaping @Sendable (Data) throws -> Void = { _ in }
        ) -> ReadingSnapshotPublisher {
            ReadingSnapshotPublisher(
                storage: storage ?? ReadingSnapshotStorage(
                    read: { [self] file in files.withLock { $0[file] } },
                    replace: { [self] file, data in files.withLock { $0[file] = data } }
                ),
                now: { Date(timeIntervalSince1970: 1_788_652_800) },
                makeGeneration: { UUID() },
                requestReload: requestReload ?? { [self] _ in
                    reloads.withLock {
                        $0 += 1
                    }
                },
                sendWatchContext: sendWatchContext
            )
        }

        func publish(using publisher: ReadingSnapshotPublisher) async throws {
            let root = URL(filePath: #filePath).deletingLastPathComponent()
                .deletingLastPathComponent().deletingLastPathComponent()
            let data = try Data(contentsOf: root.appending(path: "Contracts/Deluxe/content.json"))
            let fixture = try ReadingSnapshotCodec.decode(data)
            _ = try await publisher.publish(items: fixture.items, totalEligibleCount: 3, authorization: authorization)
        }
    }
}
