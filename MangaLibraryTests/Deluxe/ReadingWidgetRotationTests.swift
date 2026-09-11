import Foundation
import Testing
@testable import MangaLibrary

@Suite("Bounded reading widget rotation", .tags(.fast))
struct ReadingWidgetRotationTests {
    @Test
    func `a reload inside a slot schedules one hour on the original five minute boundaries`() throws {
        let rotation = ReadingWidgetRotation(snapshot: try Self.snapshot())

        let dates = rotation.timelineDates(at: Self.date(317))

        let expectedOffsets: [TimeInterval] = [
            300, 600, 900, 1_200, 1_500, 1_800, 2_100, 2_400, 2_700, 3_000, 3_300, 3_600, 3_900
        ]
        #expect(dates == expectedOffsets.map(Self.date))
    }

    @Test(arguments: [
        (0.0, [10, 20, 30, 40]),
        (299.999, [10, 20, 30, 40]),
        (300.0, [20, 30, 40, 10]),
        (900.0, [40, 10, 20, 30]),
        (1_200.0, [10, 20, 30, 40]),
        (3_600.0, [10, 20, 30, 40])
    ])
    func `every slot advances one reading and wraps`(elapsed: TimeInterval, expected: [Int64]) throws {
        let rotation = ReadingWidgetRotation(snapshot: try Self.snapshot())

        #expect(rotation.items(at: Self.date(elapsed)).map(\.mangaID) == expected)
    }

    @Test
    func `a preferred reading starts first and the next window overlaps it by one position`() throws {
        let rotation = ReadingWidgetRotation(snapshot: try Self.snapshot(preferred: 30))

        #expect(rotation.items(at: Self.date(0)).map(\.mangaID) == [30, 40, 10, 20])
        #expect(rotation.items(at: Self.date(300)).map(\.mangaID) == [40, 10, 20, 30])
    }

    @Test
    func `a delayed renewal resumes the stable phase instead of restarting at the preferred manga`() throws {
        let snapshot = try Self.snapshot(preferred: 30)
        let initial = ReadingWidgetRotation(snapshot: snapshot)
        let renewed = ReadingWidgetRotation(snapshot: snapshot)

        #expect(initial.items(at: Self.date(317)).map(\.mangaID) == [40, 10, 20, 30])
        #expect(renewed.items(at: Self.date(7_530)).map(\.mangaID) == [40, 10, 20, 30])
        #expect(renewed.timelineDates(at: Self.date(7_530)).first == Self.date(7_500))
        #expect(renewed.timelineDates(at: Self.date(7_530)).last == Self.date(11_100))
    }

    @Test
    func `a visible publication resets the phase to its updated reading`() throws {
        let previous = ReadingWidgetRotation(snapshot: try Self.snapshot())
        let updated = ReadingWidgetRotation(snapshot: try Self.snapshot(anchor: 600, revision: 2, preferred: 20))

        #expect(previous.items(at: Self.date(601)).map(\.mangaID) == [30, 40, 10, 20])
        #expect(updated.items(at: Self.date(601)).map(\.mangaID) == [20, 30, 40, 10])
        #expect(updated.timelineDates(at: Self.date(601)).first == Self.date(600))
    }

    @Test
    func `clock rollback keeps the preferred reading and never schedules the initial entry in the future`() throws {
        let rotation = ReadingWidgetRotation(snapshot: try Self.snapshot(preferred: 30))

        #expect(rotation.items(at: Self.date(-60)).map(\.mangaID) == [30, 40, 10, 20])
        let expectedOffsets: [TimeInterval] = [
            -60, 300, 600, 900, 1_200, 1_500, 1_800, 2_100, 2_400, 2_700, 3_000, 3_300, 3_600
        ]
        #expect(rotation.timelineDates(at: Self.date(-60)) == expectedOffsets.map(Self.date))
    }

    @Test(arguments: [ReadingSnapshot.State.empty, .redacted, .unavailable])
    func `states without readings request no scheduled rotation`(_ state: ReadingSnapshot.State) throws {
        let rotation = ReadingWidgetRotation(snapshot: try Self.snapshot(ids: [], state: state))

        #expect(rotation.timelineDates(at: Self.date(317)) == [Self.date(317)])
        #expect(rotation.items(at: Self.date(317)).isEmpty)
        #expect(rotation.coverResourceIDs(at: Self.date(317), maximumVisibleCount: 6).isEmpty)
    }

    @Test
    func `a single reading stays visible without a periodic timeline`() throws {
        let rotation = ReadingWidgetRotation(snapshot: try Self.snapshot(ids: [20], preferred: 20))

        #expect(rotation.timelineDates(at: Self.date(7_530)) == [Self.date(7_530)])
        #expect(rotation.items(at: Self.date(7_530)).map(\.mangaID) == [20])
        #expect(rotation.coverResourceIDs(at: Self.date(7_530), maximumVisibleCount: 6) == [Self.cover(20)])
    }

    @Test
    func `large windows prepare at most eighteen cover positions across the bounded horizon`() throws {
        let rotation = ReadingWidgetRotation(snapshot: try Self.snapshot(ids: Array(1...20), preferred: 15))

        let resources = rotation.coverResourceIDs(at: Self.date(0), maximumVisibleCount: 6)

        #expect(resources == [15, 16, 17, 18, 19, 20, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12].map(Self.cover))
    }

    @Test(arguments: [
        (1, [16, 17, 18, 19, 20, 1, 2, 3, 4, 5, 6, 7, 8]),
        (3, [16, 17, 18, 19, 20, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
    ])
    func `cover preparation starts in the current slot and respects the family capacity`(
        capacity: Int,
        expected: [Int64]
    ) throws {
        let rotation = ReadingWidgetRotation(snapshot: try Self.snapshot(ids: Array(1...20), preferred: 15))

        #expect(
            rotation.coverResourceIDs(at: Self.date(317), maximumVisibleCount: capacity) == expected.map(Self.cover)
        )
    }

    @Test
    func `repeated and absent covers do not replace readings or multiply resource decoding`() throws {
        let snapshot = try Self.snapshot(covers: [Self.cover(10), nil, Self.cover(10), Self.cover(40)])
        let rotation = ReadingWidgetRotation(snapshot: snapshot)

        #expect(rotation.items(at: Self.date(300)).prefix(2).map(\.mangaID) == [20, 30])
        #expect(
            rotation.coverResourceIDs(at: Self.date(300), maximumVisibleCount: 3) == [Self.cover(10), Self.cover(40)]
        )
    }
}

private extension ReadingWidgetRotationTests {
    static func date(_ offset: TimeInterval) -> Date {
        Date(timeIntervalSince1970: 1_800_000_000 + offset)
    }

    static func cover(_ id: Int64) -> String {
        let suffix = String(id, radix: 16)
        return String(repeating: "0", count: 64 - suffix.count) + suffix
    }

    static func snapshot(
        ids: [Int64] = [10, 20, 30, 40],
        state: ReadingSnapshot.State = .content,
        anchor: TimeInterval = 0,
        revision: UInt64 = 1,
        preferred: Int64? = nil,
        covers: [String?]? = nil
    ) throws -> ReadingSnapshot {
        let items = try ids.enumerated().map { index, id in
            try ReadingSnapshot.Item(
                mangaID: id,
                title: "Reading \(id)",
                readingVolume: 1,
                totalVolumes: 12,
                coverResourceID: covers.map { $0[index] } ?? cover(id)
            )
        }
        return try ReadingSnapshot(
            publicationGeneration: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
            revision: revision,
            sessionGeneration: state == .unavailable ? nil : UUID(uuidString: "22222222-2222-4222-8222-222222222222")!,
            state: state,
            generatedAt: date(anchor),
            totalEligibleCount: state == .content || state == .empty ? Int64(items.count) : nil,
            items: items,
            preferredStartMangaID: preferred
        )
    }
}
