//
//  ReadingSnapshotCodecTests.swift
//  MangaLibraryTests
//

import Foundation
import Testing
@testable import MangaLibrary

@Suite("Deluxe reading contract", .tags(.fast))
struct ReadingSnapshotCodecTests {
    @Test(arguments: ["content", "empty", "redacted", "unavailable", "uint64-max"])
    func `accepts approved contract examples`(_ fixture: String) throws {
        let data = try DeluxeContractFixtures.data(fixture)

        #expect(throws: Never.self) {
            _ = try ReadingSnapshotCodec.encode(ReadingSnapshotCodec.decode(data))
        }
    }

    @Test(
        arguments: [
            "future-format", "future-state", "invalid-reading", "invalid-total",
            "invalid-duplicate-id", "invalid-revision-overflow"
        ]
    )
    func `rejects incompatible examples as a whole`(_ fixture: String) throws {
        let data = try DeluxeContractFixtures.data(fixture)

        #expect(throws: (any Error).self) {
            try ReadingSnapshotCodec.decode(data)
        }
    }

    @Test
    func `preserves the final UInt64 revision in emitted JSON`() throws {
        let snapshot = try ReadingSnapshotCodec.decode(DeluxeContractFixtures.data("uint64-max"))
        let encoded = try ReadingSnapshotCodec.encode(snapshot)
        let json = try #require(String(data: encoded, encoding: .utf8))

        #expect(json.contains(#""revision":18446744073709551615"#))
    }

    @Test
    func `unsafe cover references degrade without losing the reading`() throws {
        let snapshot = try ReadingSnapshotCodec.decode(DeluxeContractFixtures.data("cover-fallback"))
        let encoded = try ReadingSnapshotCodec.encode(snapshot)
        let json = try #require(String(data: encoded, encoding: .utf8))

        #expect(json.contains("../outside.jpg") == false)
        #expect(json.contains(#""coverResourceID":null"#))
        #expect(snapshot.items.map(\.mangaID) == [20, 10, 30])
    }

    @Test(arguments: ["fence-open-a", "fence-closed", "fence-open-b"])
    func `accepts the independent fence examples`(_ fixture: String) throws {
        let data = try DeluxeContractFixtures.data(fixture)

        #expect(throws: Never.self) {
            _ = try ReadingSnapshotCodec.encodeFence(ReadingSnapshotCodec.decodeFence(data))
        }
    }

    @Test
    func `closed fence emits explicit denial`() throws {
        let fence = try ReadingSnapshotCodec.decodeFence(DeluxeContractFixtures.data("fence-closed"))
        let json = try #require(String(data: ReadingSnapshotCodec.encodeFence(fence), encoding: .utf8))

        #expect(json.contains(#""allowedSessionGeneration":null"#))
    }

    @Test(arguments: ["", " ", " Alba", "Alba\n", String(repeating: "é", count: 257)])
    func `rejects titles outside the prepared presentation contract`(_ title: String) {
        #expect(throws: ReadingSnapshotError.invalidTitle) {
            try ReadingSnapshot.Item(
                mangaID: 1,
                title: title,
                readingVolume: 1,
                totalVolumes: nil,
                coverResourceID: nil
            )
        }
    }

    @Test(arguments: [(0, Optional<Int>.none), (301, nil), (2, 1), (1, 0), (1, 301)])
    func `constructors reject impossible reading positions`(_ readingVolume: Int, _ totalVolumes: Int?) {
        #expect(throws: (any Error).self) {
            try ReadingSnapshot.Item(
                mangaID: 1,
                title: nil,
                readingVolume: readingVolume,
                totalVolumes: totalVolumes,
                coverResourceID: nil
            )
        }
    }

    @Test
    func `constructors reject empty content and absent session`() throws {
        #expect(throws: ReadingSnapshotError.invalidState) {
            try ReadingSnapshot(
                publicationGeneration: DeluxeContractFixtures.publicationGeneration,
                revision: 1,
                sessionGeneration: nil,
                state: .content,
                generatedAt: DeluxeContractFixtures.date,
                totalEligibleCount: 0,
                items: []
            )
        }
    }

    @Test
    func `zero fence revision cannot authorize a publication`() throws {
        #expect(throws: ReadingSnapshotError.invalidRevision) {
            try SessionFence(
                publicationGeneration: DeluxeContractFixtures.publicationGeneration,
                fenceRevision: 0,
                allowedSessionGeneration: nil
            )
        }
    }

    @Test(
        arguments: [
            ("\"revision\": 7", "\"revision\": 0"),
            ("\"revision\": 7", "\"revision\": 1.5"),
            ("\"totalEligibleCount\": 3", "\"totalEligibleCount\": 2"),
            ("\"totalEligibleCount\": 3", "\"totalEligibleCount\": -1"),
            ("\"sessionGeneration\": \"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa\"", "\"sessionGeneration\": null"),
            ("2026-09-06T00:00:00.000Z", "2026-02-30T00:00:00.000Z"),
            ("2026-09-06T00:00:00.000Z", "2026-09-06T00:00:00Z"),
            ("2026-09-06T00:00:00.000Z", "2026-09-06T02:00:00.000+02:00")
        ]
    )
    func `decoding cannot bypass envelope invariants`(_ source: String, _ replacement: String) throws {
        let data = try DeluxeContractFixtures.replacing(source, with: replacement, in: "content")

        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(ReadingSnapshot.self, from: data)
        }
    }

    @Test
    func `nullable fields remain mandatory wire keys`() throws {
        let data = try DeluxeContractFixtures.replacing("\"title\": null,", with: "", in: "content")

        #expect(throws: (any Error).self) {
            try ReadingSnapshotCodec.decode(data)
        }
    }

    @Test
    func `rejects invalid UTF8 before JSON decoding`() {
        #expect(throws: ReadingSnapshotError.invalidUTF8) {
            try ReadingSnapshotCodec.decode(Data([0xFF]))
        }
    }

    @Test
    func `enforces JSON byte limit before ignoring additional keys`() throws {
        let atLimit = try DeluxeContractFixtures.paddedContent(byteCount: 32_768)
        let aboveLimit = try DeluxeContractFixtures.paddedContent(byteCount: 32_769)

        #expect(throws: Never.self) {
            try ReadingSnapshotCodec.decode(atLimit)
        }
        #expect(throws: ReadingSnapshotError.payloadTooLarge) {
            try ReadingSnapshotCodec.decode(aboveLimit)
        }
    }

    @Test(arguments: [(32_697, 32_768), (32_698, 32_769)])
    func `context budget includes the binary plist envelope`(_ jsonBytes: Int, _ expectedBytes: Int) throws {
        let data = try DeluxeContractFixtures.paddedContent(byteCount: jsonBytes)
        let snapshot = try ReadingSnapshotCodec.decode(data)

        #expect(snapshot.state == .content)
        #expect(try ReadingSnapshotCodec.contextByteCount(for: data) == expectedBytes)
    }
}

private enum DeluxeContractFixtures {
    static var publicationGeneration: UUID {
        UUID(uuid: (0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x41, 0x11, 0x81, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11))
    }

    static let date = Date(timeIntervalSince1970: 1_788_652_800)

    static func data(_ name: String) throws -> Data {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try Data(contentsOf: repository.appending(path: "Contracts/Deluxe/\(name).json"))
    }

    static func replacing(_ source: String, with replacement: String, in fixture: String) throws -> Data {
        let json = try #require(String(data: data(fixture), encoding: .utf8))
        try #require(json.contains(source))
        return Data(json.replacingOccurrences(of: source, with: replacement).utf8)
    }

    static func paddedContent(byteCount: Int) throws -> Data {
        let json = try #require(String(data: data("content"), encoding: .utf8))
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = String(trimmed.dropLast()) + ",\"additional\":\""
        let suffix = "\"}"
        let paddingCount = byteCount - prefix.utf8.count - suffix.utf8.count
        try #require(paddingCount >= 0)
        return Data((prefix + String(repeating: "x", count: paddingCount) + suffix).utf8)
    }
}
