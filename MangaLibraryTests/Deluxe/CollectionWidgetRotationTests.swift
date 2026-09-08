import Foundation
import Testing
@testable import MangaLibrary

@Suite("Complete collection widget rotation", .tags(.fast))
struct CollectionWidgetRotationTests {
    @Test
    func `the collection advances across the entire payload beyond the reading transport prefix`() throws {
        let rotation = CollectionWidgetRotation(snapshot: try Self.snapshot(count: 200), generatedAt: Self.date(0))

        #expect(rotation.item(at: Self.date(0))?.mangaID == 1)
        #expect(rotation.item(at: Self.date(299))?.mangaID == 1)
        #expect(rotation.item(at: Self.date(300))?.mangaID == 2)
        #expect(rotation.item(at: Self.date(59_700))?.mangaID == 200)
        #expect(rotation.item(at: Self.date(60_000))?.mangaID == 1)
    }

    @Test
    func `renewal retains the original phase and prepares only thirteen cover positions`() throws {
        let rotation = CollectionWidgetRotation(snapshot: try Self.snapshot(count: 20), generatedAt: Self.date(0))

        let expectedOffsets: [TimeInterval] = [
            7_500, 7_800, 8_100, 8_400, 8_700, 9_000, 9_300, 9_600, 9_900, 10_200, 10_500, 10_800, 11_100
        ]
        #expect(rotation.timelineDates(at: Self.date(7_530)) == expectedOffsets.map(Self.date))
        #expect(rotation.item(at: Self.date(7_530))?.mangaID == 6)
        #expect(rotation.coverResourceIDs(at: Self.date(7_530)) == (6...18).map(Self.cover))
    }

    @Test
    func `a new publication restarts collection order and a backward clock never skips its first card`() throws {
        let snapshot = try Self.snapshot(count: 3)
        let previous = CollectionWidgetRotation(snapshot: snapshot, generatedAt: Self.date(0))
        let updated = CollectionWidgetRotation(snapshot: snapshot, generatedAt: Self.date(600))

        #expect(previous.item(at: Self.date(601))?.mangaID == 3)
        #expect(updated.item(at: Self.date(601))?.mangaID == 1)
        #expect(updated.item(at: Self.date(540))?.mangaID == 1)
        #expect(updated.timelineDates(at: Self.date(540)).first == Self.date(540))
        #expect(updated.timelineDates(at: Self.date(540)).dropFirst().first == Self.date(900))
    }

    @Test
    func `zero and one collection manga need no periodic refresh`() throws {
        let empty = CollectionWidgetRotation(snapshot: try Self.snapshot(count: 0), generatedAt: Self.date(0))
        let single = CollectionWidgetRotation(snapshot: try Self.snapshot(count: 1), generatedAt: Self.date(0))

        #expect(empty.item(at: Self.date(600)) == nil)
        #expect(empty.coverResourceIDs(at: Self.date(600)).isEmpty)
        #expect(empty.timelineDates(at: Self.date(600)) == [Self.date(600)])
        #expect(single.item(at: Self.date(600))?.mangaID == 1)
        #expect(single.timelineDates(at: Self.date(600)) == [Self.date(600)])
    }
}

private extension CollectionWidgetRotationTests {
    static func date(_ offset: TimeInterval) -> Date { Date(timeIntervalSince1970: 1_800_000_000 + offset) }

    static func cover(_ id: Int) -> String {
        let suffix = String(id, radix: 16)
        return String(repeating: "0", count: 64 - suffix.count) + suffix
    }

    static func snapshot(count: Int) throws -> CollectionWidgetSnapshot {
        try CollectionWidgetSnapshot(items: (0..<count).map { index in
            try CollectionWidgetSnapshot.Item(
                mangaID: Int64(index + 1),
                title: "Manga \(index + 1)",
                ownedVolumeCount: 2,
                totalVolumes: 10,
                isComplete: false,
                coverResourceID: cover(index + 1)
            )
        })
    }
}
