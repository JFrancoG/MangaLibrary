import Foundation
import Synchronization
import Testing
@testable import MangaLibrary

@Suite("Durable reading publication", .tags(.integration))
struct ReadingSnapshotPublisherTests {
    @Test
    func `publication survives restart and identical projection is a no op`() async throws {
        let harness = try makeHarness()
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let snapshot = try fixture()
        let publisher = harness.publisher()

        _ = try await publisher.publish(
            items: snapshot.items,
            totalEligibleCount: 3,
            authorization: harness.gate.authorization(for: harness.authority)
        )
        let reader = ReadingSnapshotReader(storage: harness.storage)
        #expect(try reader.read()?.items.map(\.mangaID) == [20, 10, 30])

        let relaunched = harness.publisher()
        #expect(try await relaunched.recover() == .ready)
        let result = try await relaunched.publish(
            items: snapshot.items,
            totalEligibleCount: 3,
            authorization: harness.gate.authorization(for: harness.authority)
        )
        #expect(result == nil)
        #expect(harness.reloads.withLock { $0.count } == 1)
        #expect(try reader.read()?.revision == 1)
    }

    @Test
    func `verified retirement denies the old manifest before redaction`() async throws {
        let harness = try makeHarness()
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let snapshot = try fixture()
        let publisher = harness.publisher()
        _ = try await publisher.publish(
            items: snapshot.items,
            totalEligibleCount: 3,
            authorization: harness.gate.authorization(for: harness.authority)
        )
        let authorization = try #require(harness.gate.suspendForLogout(harness.authority))
        let commit = try await publisher.close(authorization: authorization)

        #expect(try ReadingSnapshotReader(storage: harness.storage).read() == nil)
        let relaunched = harness.publisher()
        #expect(try await relaunched.recover() == .retirementPending(harness.authority.generation))
        try await relaunched.finishRetirement(commit)
        let raw = try #require(try harness.storage.read(.snapshot))
        #expect(try ReadingSnapshotCodec.decode(raw).state == .redacted)
        #expect(try await harness.publisher().recover() == .ready)
    }

    @Test
    func `reader rejects a fence that changes around the manifest`() throws {
        let initial = try fixtureData("fence-open-a")
        let final = try fixtureData("fence-closed")
        let content = try fixtureData("content")
        let remaining = Mutex([initial, final])
        let reader = ReadingSnapshotReader(
            readFence: {
                remaining.withLock {
                    $0.removeFirst()
                }
            },
            readSnapshot: { content }
        )

        #expect(try reader.read() == nil)
        #expect(remaining.withLock { $0.isEmpty })
    }

    @Test
    func `failed manifest preserves content and consumes its reserved revision`() async throws {
        let harness = try makeHarness()
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let snapshot = try fixture()
        _ = try await harness.publisher().publish(
            items: snapshot.items,
            totalEligibleCount: 3,
            authorization: harness.gate.authorization(for: harness.authority)
        )
        let failing = ReadingSnapshotStorage(
            read: harness.storage.read,
            replace: { file, data in
                guard file != .snapshot else { throw ReadingSnapshotStorageError.unavailable }
                try harness.storage.replace(file, data)
            }
        )
        await #expect(throws: (any Error).self) {
            try await harness.publisher(storage: failing).publish(
                items: [],
                totalEligibleCount: 0,
                authorization: harness.gate.authorization(for: harness.authority)
            )
        }
        #expect(try ReadingSnapshotReader(storage: harness.storage).read()?.items.count == 3)
        #expect(harness.reloads.withLock { $0.count } == 1)

        let result = try await harness.publisher().publish(
            items: [],
            totalEligibleCount: 0,
            authorization: harness.gate.authorization(for: harness.authority)
        )
        #expect(result?.revision == 3)
        #expect(try ReadingSnapshotReader(storage: harness.storage).read()?.state == .empty)
    }

    @Test
    func `restart repeats a pending reload without reserving another revision`() async throws {
        let harness = try makeHarness()
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let snapshot = try fixture()
        let publisher = harness.publisher(reload: { _ in
            throw ReadingSnapshotStorageError.unavailable
        })
        _ = try await publisher.publish(
            items: snapshot.items,
            totalEligibleCount: 3,
            authorization: harness.gate.authorization(for: harness.authority)
        )
        #expect(try ReadingSnapshotReader(storage: harness.storage).read()?.revision == 1)
        let relaunched = harness.publisher()
        #expect(try await relaunched.recover() == .ready)
        #expect(harness.reloads.withLock { $0.count } == 1)
        #expect(try ReadingSnapshotReader(storage: harness.storage).read()?.revision == 1)
        #expect(try await relaunched.recover() == .ready)
        #expect(harness.reloads.withLock { $0.count } == 1)
    }

    @Test
    func `late publication and retirement cannot replace a newer session`() async throws {
        let harness = try makeHarness()
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let snapshot = try fixture()
        let publisher = harness.publisher()
        let stale = harness.gate.authorization(for: harness.authority)
        _ = try await publisher.publish(items: snapshot.items, totalEligibleCount: 3, authorization: stale)
        let outgoing = try #require(harness.gate.suspendForLogout(harness.authority))
        let retirement = try await publisher.close(authorization: outgoing)
        try await publisher.finishRetirement(retirement)
        let next = SessionAuthority(userID: harness.authority.userID, generation: UUID())
        harness.gate.activate(next)
        _ = try await publisher.publish(
            items: [],
            totalEligibleCount: 0,
            authorization: harness.gate.authorization(for: next)
        )
        await #expect(throws: (any Error).self) {
            try await publisher.publish(items: snapshot.items, totalEligibleCount: 3, authorization: stale)
        }
        let lateRetirement = try await publisher.close(authorization: outgoing)
        try await publisher.finishRetirement(lateRetirement)
        try await publisher.finishRetirement(retirement)
        let current = try #require(try ReadingSnapshotReader(storage: harness.storage).read())
        #expect(current.sessionGeneration == next.generation)
        #expect(current.state == .empty)
    }

    @Test(arguments: [false, true])
    func `retiring an unpublished B preserves the last redaction recipient A`(_ reloadFails: Bool) async throws {
        let harness = try makeHarness()
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let snapshot = try fixture()
        _ = try await harness.publisher().publish(
            items: snapshot.items,
            totalEligibleCount: 3,
            authorization: harness.gate.authorization(for: harness.authority)
        )
        let retiringA = harness.publisher(reload: { data in
            if reloadFails {
                throw ReadingSnapshotStorageError.unavailable
            }
            harness.reloads.withLock {
                $0.append(data)
            }
        })
        let authorizationA = try #require(harness.gate.suspendForLogout(harness.authority))
        let commitA = try await retiringA.close(authorization: authorizationA)
        try await retiringA.finishRetirement(commitA)
        let previousData = try #require(try harness.storage.read(.snapshot))
        let previousRedaction = try ReadingSnapshotCodec.decode(previousData)
        let authorityB = SessionAuthority(userID: harness.authority.userID, generation: UUID())
        harness.gate.activate(authorityB)
        let authorizationB = try #require(harness.gate.suspendForLogout(authorityB))
        let retiringB = harness.publisher()

        let commitB = try await retiringB.close(authorization: authorizationB)
        try await retiringB.finishRetirement(commitB)

        let deliveredData = try #require(harness.reloads.withLock { $0.last })
        let delivered = try ReadingSnapshotCodec.decode(deliveredData)
        #expect(delivered.state == .redacted)
        #expect(delivered.sessionGeneration == harness.authority.generation)
        #expect(delivered.revision > previousRedaction.revision)
        #expect(try ReadingSnapshotReader(storage: harness.storage).read() == nil)
    }

    @Test
    func `inaccessible state does not rotate a readable publication`() async throws {
        let harness = try makeHarness()
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let snapshot = try fixture()
        _ = try await harness.publisher().publish(
            items: snapshot.items,
            totalEligibleCount: 3,
            authorization: harness.gate.authorization(for: harness.authority)
        )
        let before = try harness.storage.read(.fence)
        let failing = ReadingSnapshotStorage(
            read: { file in
                guard file != .publisherState else { throw ReadingSnapshotStorageError.unavailable }
                return try harness.storage.read(file)
            },
            replace: harness.storage.replace
        )
        await #expect(throws: (any Error).self) {
            try await harness.publisher(storage: failing).recover()
        }
        #expect(try harness.storage.read(.fence) == before)
    }

    @Test
    func `lost publisher metadata with closed fence never restores authority`() async throws {
        let harness = try makeHarness()
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let publisher = harness.publisher()
        _ = try await publisher.recover()
        try harness.storage.replace(.publisherState, Data("broken".utf8))

        #expect(try await harness.publisher().recover() == .retirementRequired)
        #expect(try ReadingSnapshotReader(storage: harness.storage).read() == nil)
    }

    @Test(arguments: [ReservedCounter.publication, .fence])
    func `overflow retirement is durable at its first verified closed fence`(_ counter: ReservedCounter) async throws {
        let harness = try makeHarness()
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let snapshot = try fixture()
        let original = try await harness.publisher().publish(
            items: snapshot.items,
            totalEligibleCount: 3,
            authorization: harness.gate.authorization(for: harness.authority)
        )
        let originalEpoch = try #require(original?.publicationGeneration)
        try exhaust(counter, in: harness.storage)
        let verifiedClosure = Mutex(false)
        let failing = ReadingSnapshotStorage(
            read: { file in
                let data = try harness.storage.read(file)
                if file == .fence, let data {
                    let fence = try ReadingSnapshotCodec.decodeFence(data)
                    if fence.publicationGeneration != originalEpoch, fence.allowedSessionGeneration == nil {
                        verifiedClosure.withLock {
                            $0 = true
                        }
                    }
                }
                return data
            },
            replace: { file, data in
                if file == .publisherState, verifiedClosure.withLock({ $0 }) {
                    throw PublicationFileFault.afterVerifiedClosure
                }
                try harness.storage.replace(file, data)
            }
        )
        let authorization = try #require(harness.gate.suspendForLogout(harness.authority))

        await #expect(throws: Never.self) {
            try await harness.publisher(storage: failing).close(authorization: authorization)
        }

        try #require(verifiedClosure.withLock { $0 })
        #expect(try ReadingSnapshotReader(storage: harness.storage).read() == nil)
        #expect(try await harness.publisher().recover() == .retirementPending(harness.authority.generation))
    }

    @Test
    func `recovery rotates when the manifest proves the revision counter moved backwards`() async throws {
        let harness = try makeHarness()
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let snapshot = try fixture()
        let original = try await harness.publisher().publish(
            items: snapshot.items,
            totalEligibleCount: 3,
            authorization: harness.gate.authorization(for: harness.authority)
        )
        let originalEpoch = try #require(original?.publicationGeneration)
        try rollBackPublicationCounter(in: harness.storage)

        _ = try await harness.publisher().recover()

        let data = try #require(try harness.storage.read(.fence))
        let fence = try ReadingSnapshotCodec.decodeFence(data)
        #expect(fence.publicationGeneration != originalEpoch)
        #expect(fence.allowedSessionGeneration == nil)
        #expect(try ReadingSnapshotReader(storage: harness.storage).read() == nil)
    }

    @Test
    func `an identical projection repairs a backwards counter instead of returning a no op`() async throws {
        let harness = try makeHarness()
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let snapshot = try fixture()
        let authorization = harness.gate.authorization(for: harness.authority)
        let original = try await harness.publisher().publish(
            items: snapshot.items,
            totalEligibleCount: 3,
            authorization: authorization
        )
        let originalEpoch = try #require(original?.publicationGeneration)
        try rollBackPublicationCounter(in: harness.storage)

        let result = try await harness.publisher().publish(
            items: snapshot.items,
            totalEligibleCount: 3,
            authorization: authorization
        )

        let replacement = try #require(result)
        #expect(replacement.publicationGeneration != originalEpoch)
        #expect(replacement.revision == 1)
        #expect(try ReadingSnapshotReader(storage: harness.storage).read()?.items.map(\.mangaID) == [20, 10, 30])
        #expect(harness.reloads.withLock { $0.count } == 2)
    }

    @Test
    func `a missing fence and corrupt metadata cannot turn a previous retirement into bootstrap`() async throws {
        let harness = try makeHarness()
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let snapshot = try fixture()
        let publisher = harness.publisher()
        _ = try await publisher.publish(
            items: snapshot.items,
            totalEligibleCount: 3,
            authorization: harness.gate.authorization(for: harness.authority)
        )
        let authorization = try #require(harness.gate.suspendForLogout(harness.authority))
        _ = try await publisher.close(authorization: authorization)
        try harness.storage.replace(.publisherState, Data("broken".utf8))
        try FileManager.default.removeItem(at: harness.directory.appending(path: "shared/session-fence.json"))

        #expect(try await harness.publisher().recover() == .retirementRequired)
        #expect(try ReadingSnapshotReader(storage: harness.storage).read() == nil)
    }

    @Test
    func `a new publication repairs an oversized manifest`() async throws {
        let harness = try makeHarness()
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let snapshot = try fixture()
        _ = try await harness.publisher().publish(
            items: snapshot.items,
            totalEligibleCount: 3,
            authorization: harness.gate.authorization(for: harness.authority)
        )
        let manifestURL = harness.directory.appending(path: "shared/reading-snapshot.json")
        try Data(repeating: 0x20, count: 32_769).write(to: manifestURL)

        _ = try await harness.publisher().publish(
            items: [],
            totalEligibleCount: 0,
            authorization: harness.gate.authorization(for: harness.authority)
        )

        let repaired = try #require(try ReadingSnapshotReader(storage: harness.storage).read())
        #expect(repaired.state == .empty)
        #expect(harness.reloads.withLock { $0.count } == 2)
    }

    @Test(arguments: [ReservedCounter.publication, .fence])
    func `ordinary publication rotates an exhausted counter before opening the new epoch`(
        _ counter: ReservedCounter
    ) async throws {
        let harness = try makeHarness()
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let snapshot = try fixture()
        let original = try await harness.publisher().publish(
            items: snapshot.items,
            totalEligibleCount: 3,
            authorization: harness.gate.authorization(for: harness.authority)
        )
        let originalEpoch = try #require(original?.publicationGeneration)
        try exhaust(counter, in: harness.storage)

        let result = try await harness.publisher().publish(
            items: [],
            totalEligibleCount: 0,
            authorization: harness.gate.authorization(for: harness.authority)
        )

        let replacement = try #require(result)
        #expect(replacement.publicationGeneration != originalEpoch)
        #expect(replacement.revision == 1)
        #expect(try ReadingSnapshotReader(storage: harness.storage).read()?.state == .empty)
    }

    private func rollBackPublicationCounter(in storage: ReadingSnapshotStorage) throws {
        let data = try #require(try storage.read(.publisherState))
        var state = try JSONDecoder().decode(ReadingPublisherState.self, from: data)
        state.lastReservedRevision = 0
        try storage.replace(.publisherState, JSONEncoder().encode(state))
    }

    private func exhaust(_ counter: ReservedCounter, in storage: ReadingSnapshotStorage) throws {
        let data = try #require(try storage.read(.publisherState))
        var state = try JSONDecoder().decode(ReadingPublisherState.self, from: data)
        switch counter {
        case .publication:
            state.lastReservedRevision = .max
        case .fence:
            state.lastReservedFenceRevision = .max
        }
        try storage.replace(.publisherState, JSONEncoder().encode(state))
    }

    enum ReservedCounter {
        case publication
        case fence
    }

    private enum PublicationFileFault: Error {
        case afterVerifiedClosure
    }

    private func makeHarness() throws -> Harness {
        let directory = FileManager.default.temporaryDirectory.appending(path: "deluxe-\(UUID().uuidString)")
        let source = try fixture()
        let authority = SessionAuthority(userID: UUID(), generation: try #require(source.sessionGeneration))
        return Harness(
            directory: directory,
            storage: try ReadingSnapshotStorage(directory: directory),
            authority: authority,
            gate: SessionCommitGate(activeAuthority: authority),
            reloads: Mutex([])
        )
    }

    private func fixture() throws -> ReadingSnapshot {
        try ReadingSnapshotCodec.decode(fixtureData("content"))
    }

    private func fixtureData(_ name: String) throws -> Data {
        let root = URL(filePath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        return try Data(contentsOf: root.appending(path: "Contracts/Deluxe/\(name).json"))
    }

    private final class Harness: Sendable {
        let directory: URL
        let storage: ReadingSnapshotStorage
        let authority: SessionAuthority
        let gate: SessionCommitGate
        let reloads: Mutex<[Data]>

        init(
            directory: URL,
            storage: ReadingSnapshotStorage,
            authority: SessionAuthority,
            gate: SessionCommitGate,
            reloads: consuming Mutex<[Data]>
        ) {
            self.directory = directory
            self.storage = storage
            self.authority = authority
            self.gate = gate
            self.reloads = reloads
        }

        func publisher(
            storage override: ReadingSnapshotStorage? = nil,
            reload: (@Sendable (Data) throws -> Void)? = nil
        ) -> ReadingSnapshotPublisher {
            ReadingSnapshotPublisher(
                storage: override ?? storage,
                now: { Date(timeIntervalSince1970: 1_788_652_800) },
                makeGeneration: { UUID() },
                requestReload: reload ?? { data in
                    self.reloads.withLock {
                        $0.append(data)
                    }
                }
            )
        }
    }
}
