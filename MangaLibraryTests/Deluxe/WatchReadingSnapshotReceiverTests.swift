import Foundation
import Synchronization
import Testing
@testable import MangaLibrary

@Suite("Watch reading acceptance and retirement", .tags(.fast))
struct WatchReadingSnapshotReceiverTests {
    @Test
    func `received content survives an offline relaunch without reordering the published list`() async throws {
        let cache = Cache()
        let receiver = WatchReadingSnapshotReceiver(storage: cache.storage)

        let received = await receiver.receive(Self.context())
        let relaunched = WatchReadingSnapshotReceiver(storage: cache.storage)
        let restored = await relaunched.restore()

        #expect(Self.identities(received) == [20, 10])
        #expect(Self.identities(restored) == [20, 10])
        #expect(Self.snapshot(restored)?.totalEligibleCount == 5)
        #expect(Self.snapshot(restored)?.generatedAt == Date(timeIntervalSince1970: 1_788_652_800))
    }

    @Test(arguments: [6, 7])
    func `same epoch repeats preserve the accepted display and durable cache`(_ revision: Int) async throws {
        let cache = Cache()
        let receiver = WatchReadingSnapshotReceiver(storage: cache.storage)
        try #require(Self.identities(await receiver.receive(Self.context())) == [20, 10])
        let before = cache.bytes.withLock { $0 }

        let result = await receiver.receive(Self.context(revision: revision, state: "redacted"))

        #expect(Self.identities(result) == [20, 10])
        #expect(cache.bytes.withLock { $0 } == before)
    }

    @Test
    func `retirement remains durable and rejects later content even with a higher revision`() async throws {
        let cache = Cache()
        let receiver = WatchReadingSnapshotReceiver(storage: cache.storage)
        try #require(Self.identities(await receiver.receive(Self.context())) == [20, 10])
        let redacted = await receiver.receive(Self.context(revision: 8, state: "redacted"))
        let relaunched = WatchReadingSnapshotReceiver(storage: cache.storage)
        _ = await relaunched.restore()

        let stale = await relaunched.receive(Self.context(revision: 99))

        #expect(Self.snapshot(redacted)?.state == .redacted)
        #expect(Self.snapshot(stale)?.state == .redacted)
        #expect(Self.identities(stale).isEmpty)
    }

    @Test
    func `late retirement and content from A cannot remove B or raise its visible revision`() async throws {
        let cache = Cache()
        let receiver = WatchReadingSnapshotReceiver(storage: cache.storage)
        try #require(Self.identities(await receiver.receive(Self.context())) == [20, 10])
        _ = await receiver.receive(Self.context(revision: 8, session: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"))

        let redaction = await receiver.receive(Self.context(revision: 9, state: "redacted"))
        let content = await receiver.receive(Self.context(revision: 10))
        let nextB = await receiver.receive(Self.context(revision: 11, session: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"))

        #expect(Self.snapshot(redaction)?.sessionGeneration?.uuidString.lowercased()
            == "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
        #expect(Self.snapshot(content)?.revision == 8)
        #expect(Self.snapshot(nextB)?.revision == 11)
    }

    @Test
    func `an unseen retired session cannot become eligible after its late redaction`() async {
        let cache = Cache()
        let receiver = WatchReadingSnapshotReceiver(storage: cache.storage)
        _ = await receiver.receive(Self.context(revision: 8, session: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"))
        _ = await receiver.receive(Self.context(revision: 9, state: "redacted"))
        let relaunched = WatchReadingSnapshotReceiver(storage: cache.storage)
        _ = await relaunched.restore()

        let result = await relaunched.receive(Self.context(revision: 10))

        #expect(Self.snapshot(result)?.sessionGeneration?.uuidString.lowercased()
            == "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
        #expect(Self.snapshot(result)?.revision == 8)
    }

    @Test
    func `a new epoch replaces the cache without bootstrap and the retired epoch cannot return`() async {
        let cache = Cache()
        let receiver = WatchReadingSnapshotReceiver(storage: cache.storage)
        _ = await receiver.receive(Self.context(revision: 999))
        let replacement = await receiver.receive(Self.context(
            revision: 1,
            epoch: "22222222-2222-4222-8222-222222222222"
        ))
        let relaunched = WatchReadingSnapshotReceiver(storage: cache.storage)
        _ = await relaunched.restore()

        let stale = await relaunched.receive(Self.context(revision: 1_000))

        #expect(Self.snapshot(replacement)?.revision == 1)
        #expect(Self.snapshot(stale)?.publicationGeneration.uuidString.lowercased()
            == "22222222-2222-4222-8222-222222222222")
    }

    @Test(arguments: ["empty", "redacted", "unavailable"])
    func `wire states remain distinct after cache restoration`(_ state: String) async {
        let cache = Cache()
        let receiver = WatchReadingSnapshotReceiver(storage: cache.storage)
        _ = await receiver.receive(Self.context(state: state))
        let relaunched = WatchReadingSnapshotReceiver(storage: cache.storage)

        let result = await relaunched.restore()

        #expect(Self.snapshot(result)?.state.rawValue == state)
        #expect(Self.identities(result).isEmpty)
    }

    @Test(arguments: ["malformed", "future-format", "oversized"])
    func `incompatible delivery hides cached content without becoming an empty list`(_ invalid: String) async throws {
        let cache = Cache()
        let receiver = WatchReadingSnapshotReceiver(storage: cache.storage)
        try #require(Self.identities(await receiver.receive(Self.context())) == [20, 10])
        try #require(cache.bytes.withLock { $0 } != nil)
        let data: Data
        switch invalid {
        case "future-format":
            data = Data(String(decoding: Self.context(), as: UTF8.self)
                .replacingOccurrences(of: "\"formatVersion\":1", with: "\"formatVersion\":2").utf8)
        case "oversized":
            data = Data(repeating: 32, count: 32_769)
        default:
            data = Data("broken json".utf8)
        }

        let result = await receiver.receive(data)
        let relaunched = WatchReadingSnapshotReceiver(storage: cache.storage)

        #expect(result == .unavailable)
        #expect(await relaunched.restore() == .unavailable)
        #expect(await receiver.receive(Self.context()) == .unavailable)
    }

    @Test
    func `a failed retirement cache write removes the previous content before an offline relaunch`() async throws {
        let cache = Cache()
        let receiver = WatchReadingSnapshotReceiver(storage: cache.storage)
        try #require(Self.identities(await receiver.receive(Self.context())) == [20, 10])
        try #require(cache.bytes.withLock { $0 } != nil)
        cache.failWrites.withLock { $0 = true }

        let result = await receiver.receive(Self.context(revision: 8, state: "redacted"))
        let relaunched = WatchReadingSnapshotReceiver(storage: cache.storage)

        #expect(result == .unavailable)
        #expect(cache.bytes.withLock { $0 } == nil)
        #expect(await relaunched.restore() == .unavailable)
        #expect(await receiver.receive(Self.context(revision: 99)) == .unavailable)
    }

    @Test
    func `temporarily unreadable cache is not treated as a new installation`() async throws {
        let cache = Cache()
        let receiver = WatchReadingSnapshotReceiver(storage: cache.storage)
        try #require(Self.identities(await receiver.receive(Self.context())) == [20, 10])
        try #require(cache.bytes.withLock { $0 } != nil)
        let protected = WatchReadingSnapshotStorage(
            read: { throw CacheFailure.inaccessible },
            replace: cache.storage.replace,
            discard: cache.storage.discard
        )
        let relaunched = WatchReadingSnapshotReceiver(storage: protected)

        #expect(await relaunched.restore() == .unavailable)
        #expect(await relaunched.receive(Self.context(revision: 8)) == .unavailable)
    }

    @Test
    func `corruption on disk removes the unusable cache and a subsequent valid context can recover`() async throws {
        let cache = Cache()
        let receiver = WatchReadingSnapshotReceiver(storage: cache.storage)
        try #require(Self.identities(await receiver.receive(Self.context())) == [20, 10])
        cache.bytes.withLock { $0 = Data("interrupted cache bytes".utf8) }
        let relaunched = WatchReadingSnapshotReceiver(storage: cache.storage)

        #expect(await relaunched.restore() == .unavailable)
        #expect(cache.bytes.withLock { $0 } == nil)
        let recovered = await relaunched.receive(Self.context(revision: 8))
        #expect(Self.identities(recovered) == [20, 10])
        #expect(Self.snapshot(recovered)?.revision == 8)
    }

    @Test
    func `a full retirement cache fails closed durably instead of evicting barriers`() async throws {
        let cache = Cache()
        let emptySize = Self.nearlyFullCache(retiredSessions: []).count
        // Each quoted UUID is 38 ASCII bytes, with one comma between adjacent UUIDs.
        let count = (65_536 - emptySize + 1) / 39
        let generations = (1...count).map { index in
            let digits = String(index)
            return "00000000-0000-4000-8000-" + String(repeating: "0", count: 12 - digits.count) + digits
        }
        let fixture = Self.nearlyFullCache(retiredSessions: generations)
        try #require(fixture.count <= 65_536)
        try #require(fixture.count + 39 > 65_536)
        cache.bytes.withLock { $0 = fixture }
        let receiver = WatchReadingSnapshotReceiver(storage: cache.storage)
        try #require(Self.identities(await receiver.restore()) == [20, 10])

        let result = await receiver.receive(Self.context(revision: 8, session: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"))
        let durable = try #require(cache.bytes.withLock { $0 })
        let relaunched = WatchReadingSnapshotReceiver(storage: cache.storage)

        #expect(result == .unavailable)
        #expect(durable.count <= 65_536)
        #expect(await relaunched.restore() == .unavailable)
        #expect(await relaunched.receive(Self.context(epoch: "22222222-2222-4222-8222-222222222222")) == .unavailable)
    }
}

private extension WatchReadingSnapshotReceiverTests {
    static func context(
        revision: Int = 7,
        session: String = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
        state: String = "content",
        epoch: String = "11111111-1111-4111-8111-111111111111"
    ) -> Data {
        let count = state == "content" ? "5" : state == "empty" ? "0" : "null"
        let items = state == "content" ? """
        [{"mangaID":20,"title":"Alba de papel","readingVolume":3,"totalVolumes":3,"coverResourceID":null},
        {"mangaID":10,"title":null,"readingVolume":2,"totalVolumes":null,"coverResourceID":null}]
        """ : "[]"
        return Data("""
        {"formatVersion":1,"publicationGeneration":"\(epoch)","revision":\(revision),
        "sessionGeneration":"\(session)","state":"\(state)","generatedAt":"2026-09-06T00:00:00.000Z",
        "totalEligibleCount":\(count),"items":\(items)}
        """.utf8)
    }

    static func snapshot(_ state: WatchReadingSnapshotState) -> ReadingSnapshot? {
        guard case let .snapshot(snapshot) = state else { return nil }
        return snapshot
    }

    static func identities(_ state: WatchReadingSnapshotState) -> [Int64] {
        snapshot(state)?.items.map(\.mangaID) ?? []
    }

    static func nearlyFullCache(retiredSessions: [String]) -> Data {
        let snapshot = String(decoding: context(), as: UTF8.self).replacingOccurrences(of: "\n", with: "")
        let retired = retiredSessions.map { "\"\($0)\"" }.joined(separator: ",")
        return Data("""
        {"formatVersion":1,"epoch":"11111111-1111-4111-8111-111111111111",
        "session":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","revision":7,"snapshot":\(snapshot),
        "retiredEpochs":[],"retiredSessions":[\(retired)],"saturated":false}
        """.replacingOccurrences(of: "\n", with: "").utf8)
    }

    enum CacheFailure: Error { case inaccessible }

    final class Cache: Sendable {
        let bytes = Mutex<Data?>(nil)
        let failWrites = Mutex(false)

        var storage: WatchReadingSnapshotStorage {
            WatchReadingSnapshotStorage(
                read: { self.bytes.withLock { $0 } },
                replace: { data in
                    if self.failWrites.withLock({ $0 }) {
                        throw CacheFailure.inaccessible
                    }
                    self.bytes.withLock { $0 = data }
                },
                discard: { self.bytes.withLock { $0 = nil } }
            )
        }
    }
}
