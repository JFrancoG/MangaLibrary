import Foundation
import Synchronization
import Testing
@testable import MangaLibrary

@Suite("Canonical watch delivery", .tags(.integration))
struct ReadingWatchDeliveryTests {
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

        func publisher() -> ReadingSnapshotPublisher {
            ReadingSnapshotPublisher(
                storage: ReadingSnapshotStorage(
                    read: { [self] file in files.withLock { $0[file] } },
                    replace: { [self] file, data in files.withLock { $0[file] = data } }
                ),
                now: { Date(timeIntervalSince1970: 1_788_652_800) },
                makeGeneration: { UUID() },
                requestReload: { [self] _ in reloads.withLock { $0 += 1 } }
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
