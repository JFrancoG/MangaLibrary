import Foundation
import Testing
@testable import MangaLibrary

@Suite("Complete collection wire contract", .tags(.fast))
struct CollectionWidgetSnapshotTests {
    @Test
    func `an external collection focus leads its rotation without changing canonical order`() throws {
        let suffix = #","preferredStartMangaID":20}"#
        let wire = Data((String(Self.canonicalWire.dropLast()) + suffix).utf8)
        let snapshot = try CollectionWidgetSnapshotCodec.decode(wire)
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let rotation = CollectionWidgetRotation(snapshot: snapshot, generatedAt: date)

        #expect(snapshot.items.map(\.mangaID) == [10, 20])
        #expect(rotation.item(at: date)?.mangaID == 20)
        #expect(rotation.item(at: date.addingTimeInterval(300))?.mangaID == 10)
        #expect(rotation.item(at: date.addingTimeInterval(600))?.mangaID == 20)
    }

    @Test(arguments: [0, 30])
    func `a focus absent from the collection cannot authorize a card`(_ identity: Int) {
        let suffix = #","preferredStartMangaID":\#(identity)}"#
        let wire = Data((String(Self.canonicalWire.dropLast()) + suffix).utf8)

        #expect(throws: CollectionWidgetSnapshotError.self) {
            try CollectionWidgetSnapshotCodec.decode(wire)
        }
    }

    @Test
    func `encoding preserves the complete collection in deterministic format one bytes`() throws {
        let snapshot = try CollectionWidgetSnapshot(items: [
            .init(
                mangaID: 10,
                title: "Alba",
                ownedVolumeCount: 0,
                totalVolumes: 3,
                isComplete: false
            ),
            .init(
                mangaID: 20,
                title: "Bosque",
                ownedVolumeCount: 2,
                totalVolumes: 2,
                isComplete: true
            )
        ])

        let encoded = try CollectionWidgetSnapshotCodec.encode(snapshot)

        #expect(encoded == Data(Self.canonicalWire.utf8))
        #expect(CollectionWidgetSnapshotCodec.digest(encoded) == Self.canonicalDigest)
    }

    @Test(arguments: [
        (#""mangaID":10"#, #""mangaID":0"#, CollectionWidgetSnapshotError.invalidMangaID),
        (#""ownedVolumeCount":0"#, #""ownedVolumeCount":-1"#, .invalidOwnedVolumeCount),
        (#""ownedVolumeCount":0"#, #""ownedVolumeCount":301"#, .invalidOwnedVolumeCount),
        (#""ownedVolumeCount":0"#, #""ownedVolumeCount":4"#, .invalidTotalVolumes),
        (#""totalVolumes":3"#, #""totalVolumes":0"#, .invalidTotalVolumes),
        (#""totalVolumes":3"#, #""totalVolumes":301"#, .invalidTotalVolumes),
        (#""title":"Alba""#, #""title":"""#, .invalidTitle),
        (#""title":"Alba""#, #""title":" Alba""#, .invalidTitle),
        (#""title":"Alba""#, #""title":"Alba ""#, .invalidTitle),
        (#""isComplete":false"#, #""isComplete":true"#, .invalidCompleteness),
        (#""totalVolumes":2"#, #""totalVolumes":null"#, .invalidCompleteness),
        (#""mangaID":20"#, #""mangaID":10"#, .duplicateMangaID),
        (#""formatVersion":1"#, #""formatVersion":2"#, .unsupportedFormat)
    ])
    func `invalid external values reject the whole collection instead of dropping a row`(
        original: String,
        replacement: String,
        expectedError: CollectionWidgetSnapshotError
    ) {
        let wire = Data(Self.canonicalWire.replacingOccurrences(of: original, with: replacement).utf8)

        #expect(throws: expectedError) {
            try CollectionWidgetSnapshotCodec.decode(wire)
        }
    }

    @Test(arguments: [256, 257])
    func `prepared titles use the inclusive UTF8 byte budget`(_ characterCount: Int) throws {
        let title = String(repeating: "é", count: characterCount)
        let wire = Data(Self.canonicalWire.replacingOccurrences(of: "Alba", with: title).utf8)

        if characterCount == 256 {
            let snapshot = try CollectionWidgetSnapshotCodec.decode(wire)
            #expect(snapshot.items.first?.title == title)
        } else {
            #expect(throws: CollectionWidgetSnapshotError.invalidTitle) {
                try CollectionWidgetSnapshotCodec.decode(wire)
            }
        }
    }

    @Test
    func `having every known volume does not force the explicit complete flag`() throws {
        let wire = Data(Self.canonicalWire.replacingOccurrences(
            of: #""isComplete":true"#,
            with: #""isComplete":false"#
        ).utf8)

        let snapshot = try CollectionWidgetSnapshotCodec.decode(wire)

        #expect(snapshot.items.map(\.isComplete) == [false, false])
        #expect(snapshot.items.map(\.ownedVolumeCount) == [0, 2])
    }

    @Test(arguments: ["../private", "https://example.invalid/cover.jpg", "", String(repeating: "A", count: 64)])
    func `unsafe optional cover references become placeholders without losing collection text`(_ unsafe: String) throws {
        let wire = Data(Self.canonicalWire.replacingOccurrences(
            of: #""coverResourceID":null"#,
            with: #""coverResourceID":"\#(unsafe)""#
        ).utf8)

        let snapshot = try CollectionWidgetSnapshotCodec.decode(wire)

        #expect(snapshot.items.map(\.mangaID) == [10, 20])
        #expect(snapshot.items.map(\.title) == ["Alba", "Bosque"])
        #expect(snapshot.items.allSatisfy { $0.coverResourceID == nil })
    }

    @Test(arguments: [4_096, 4_097])
    func `the item cap never produces a partial collection`(_ count: Int) throws {
        let rows = (1...count).map { id in
            #"{"mangaID":\#(id),"title":null,"ownedVolumeCount":0,"totalVolumes":null,"isComplete":false}"#
        }.joined(separator: ",")
        let wire = Data(#"{"formatVersion":1,"items":[\#(rows)]}"#.utf8)

        if count == 4_096 {
            let snapshot = try CollectionWidgetSnapshotCodec.decode(wire)
            #expect(snapshot.items.count == 4_096)
            #expect(snapshot.items.last?.mangaID == 4_096)
        } else {
            #expect(throws: CollectionWidgetSnapshotError.tooManyItems) {
                try CollectionWidgetSnapshotCodec.decode(wire)
            }
        }
    }

    @Test(arguments: [1_048_576, 1_048_577])
    func `decoding checks the complete byte limit including harmless whitespace`(_ count: Int) throws {
        let prefix = Data(#"{"formatVersion":1,"items":[]}"#.utf8)
        let wire = prefix + Data(repeating: 32, count: count - prefix.count)

        if count == 1_048_576 {
            #expect(try CollectionWidgetSnapshotCodec.decode(wire).items.isEmpty)
        } else {
            #expect(throws: CollectionWidgetSnapshotError.payloadTooLarge) {
                try CollectionWidgetSnapshotCodec.decode(wire)
            }
        }
    }

    @Test
    func `encoding rejects an oversized complete collection instead of selecting a prefix`() throws {
        let title = String(repeating: "x", count: 512)
        let items = try (1...2_000).map { id in
            try CollectionWidgetSnapshot.Item(
                mangaID: Int64(id),
                title: title,
                ownedVolumeCount: 0,
                totalVolumes: nil,
                isComplete: false
            )
        }
        let snapshot = try CollectionWidgetSnapshot(items: items)

        #expect(throws: CollectionWidgetSnapshotError.payloadTooLarge) {
            try CollectionWidgetSnapshotCodec.encode(snapshot)
        }
    }

    @Test
    func `non UTF8 input is refused before JSON interpretation`() {
        #expect(throws: CollectionWidgetSnapshotError.invalidUTF8) {
            try CollectionWidgetSnapshotCodec.decode(Data([0xff, 0xfe, 0x7b, 0x00]))
        }
    }

    @Test(arguments: [
        (-1, String(repeating: "a", count: 64), 1),
        (2, String(repeating: "a", count: 64), 1),
        (0, String(repeating: "A", count: 64), 1),
        (0, String(repeating: "g", count: 64), 1),
        (0, String(repeating: "a", count: 63), 1),
        (0, String(repeating: "a", count: 64), 0),
        (1, String(repeating: "a", count: 64), 1_048_577)
    ])
    func `invalid slot descriptors cannot authorize a resource`(slot: Int, digest: String, byteCount: Int) {
        let wire = Data(#"{"slot":\#(slot),"digest":"\#(digest)","byteCount":\#(byteCount)}"#.utf8)

        #expect(throws: CollectionWidgetSnapshotError.invalidReference) {
            try JSONDecoder().decode(CollectionWidgetSnapshot.Reference.self, from: wire)
        }
    }

    @Test
    func `a descriptor matches the exact resource and refuses same sized replacement bytes`() throws {
        let reference = try CollectionWidgetSnapshot.Reference(slot: 1, digest: Self.canonicalDigest, byteCount: 250)
        let bytes = Data(Self.canonicalWire.utf8)
        let replacement = Data(Self.canonicalWire.replacingOccurrences(of: "Alba", with: "Otro").utf8)

        #expect(CollectionWidgetSnapshotCodec.matches(bytes, reference: reference))
        #expect(!CollectionWidgetSnapshotCodec.matches(replacement, reference: reference))
        #expect(!CollectionWidgetSnapshotCodec.matches(bytes + Data([32]), reference: reference))
    }
}

private extension CollectionWidgetSnapshotTests {
    static let canonicalWire = #"{"formatVersion":1,"items":[{"coverResourceID":null,"isComplete":false,"mangaID":10,"ownedVolumeCount":0,"title":"Alba","totalVolumes":3},{"coverResourceID":null,"isComplete":true,"mangaID":20,"ownedVolumeCount":2,"title":"Bosque","totalVolumes":2}]}"#
    static let canonicalDigest = "1e3420df0c0c855b3ce7b9b812d8f3daa18c1ba9aa827c6ff0e75204616e844b"
}
