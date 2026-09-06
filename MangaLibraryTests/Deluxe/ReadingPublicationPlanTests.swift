//
//  ReadingPublicationPlanTests.swift
//  MangaLibraryTests
//

import Foundation
import Testing
@testable import MangaLibrary

@Suite("Deluxe publication byte budget", .tags(.fast))
struct ReadingPublicationPlanTests {
    @Test
    func `keeps the largest ordered prefix without skipping an expensive reading`() throws {
        let candidates = Self.candidates(count: 55, title: String(repeating: "a", count: 512))
            + [Self.candidate(mangaID: 56)]
        let first54 = Array(candidates.prefix(54))
        let first55 = Array(candidates.prefix(55))
        let skipped55 = first54 + [Self.candidate(mangaID: 56)]
        try #require(Self.oracleContext(first54, total: 56) <= 32_768)
        try #require(Self.oracleContext(first55, total: 56) > 32_768)
        try #require(Self.oracleContext(skipped55, total: 56) <= 32_768)

        let plan = try ReadingPublicationPlan(projection: Self.projection(candidates))

        #expect(plan.items.map(\.mangaID) == Array(Int64(1)...54))
        #expect(plan.totalEligibleCount == 56)
    }

    @Test
    func `counts the binary context overhead beyond otherwise acceptable JSON`() throws {
        let candidates = Self.candidates(count: 500)
        let first362 = Array(candidates.prefix(362))
        try #require(Self.oracleJSON(first362, total: 500).count <= 32_768)
        try #require(Self.oracleContext(first362, total: 500) > 32_768)
        try #require(Self.oracleContext(Array(candidates.prefix(361)), total: 500) <= 32_768)

        let plan = try ReadingPublicationPlan(projection: Self.projection(candidates))

        #expect(plan.items.map(\.mangaID) == Array(Int64(1)...361))
        #expect(plan.totalEligibleCount == 500)
    }

    @Test(arguments: [(508, Int64(56), 32_768), (509, Int64(55), 32_769)])
    func `uses the inclusive limit with room for the final revision`(
        _ finalTitleLength: Int,
        _ expectedCount: Int64,
        _ boundaryByteCount: Int
    ) throws {
        let candidates = Self.candidates(count: 55, title: String(repeating: "a", count: 492))
            + [
                Self.candidate(mangaID: 56, title: String(repeating: "a", count: finalTitleLength)),
                Self.candidate(mangaID: 57),
                Self.candidate(mangaID: 58)
            ]
        let boundary = Array(candidates.prefix(56))
        try #require(Self.oracleContext(boundary, total: 58) == boundaryByteCount)
        try #require(Self.oracleContext(boundary, total: 58, revision: 1) < 32_768)
        try #require(Self.oracleContext(Array(candidates.prefix(Int(expectedCount) + 1)), total: 58) > 32_768)

        let plan = try ReadingPublicationPlan(projection: Self.projection(candidates))

        #expect(plan.items.map(\.mangaID) == Array(Int64(1)...expectedCount))
        #expect(plan.totalEligibleCount == 58)
    }

    @Test(
        arguments: [
            (String(repeating: "\"", count: 512), Int64(29)),
            ("a" + String(repeating: "\u{0001}", count: 511), Int64(10))
        ]
    )
    func `measures JSON escapes instead of counting title bytes`(_ title: String, _ expectedCount: Int64) throws {
        let candidates = Self.candidates(count: 100, title: title)
        let accepted = Array(candidates.prefix(Int(expectedCount)))
        let rejected = Array(candidates.prefix(Int(expectedCount) + 1))
        try #require(Self.oracleContext(accepted, total: 100) <= 32_768)
        try #require(Self.oracleContext(rejected, total: 100) > 32_768)

        let plan = try ReadingPublicationPlan(projection: Self.projection(candidates))

        #expect(plan.items.map(\.mangaID) == Array(Int64(1)...expectedCount))
        #expect(plan.totalEligibleCount == 100)
    }

    @Test
    func `admitted covers reduce the prefix while absent decisions remain placeholders`() throws {
        let coverURL = try #require(URL(string: "https://covers.example.test/source.jpg"))
        let candidates = Self.candidates(count: 100, title: String(repeating: "a", count: 512), coverURL: coverURL)
        let resources = Dictionary(uniqueKeysWithValues: candidates.map { ($0.mangaID, Self.digest) })
        try #require(Self.oracleContext(Array(candidates.prefix(49)), total: 100, cover: Self.digest) <= 32_768)
        try #require(Self.oracleContext(Array(candidates.prefix(50)), total: 100, cover: Self.digest) > 32_768)

        let placeholders = try ReadingPublicationPlan(projection: Self.projection(candidates))
        let admitted = try ReadingPublicationPlan(projection: Self.projection(candidates), coverResourceIDs: resources)

        #expect(placeholders.items.map(\.mangaID) == Array(Int64(1)...54))
        #expect(placeholders.items.allSatisfy { $0.coverResourceID == nil })
        #expect(admitted.items.map(\.mangaID) == Array(Int64(1)...49))
        #expect(admitted.items.allSatisfy { $0.coverResourceID == Self.digest })
        #expect(admitted.totalEligibleCount == 100)
    }

    @Test(
        arguments: [
            "../cover.jpg",
            "https://covers.example.test/source.jpg",
            String(repeating: "A", count: 64),
            String(repeating: "a", count: 63),
            String(repeating: "a", count: 65),
            String(repeating: "a", count: 63) + "g"
        ]
    )
    func `invalid cover decisions degrade before measuring the prefix`(_ reference: String) throws {
        let candidates = Self.candidates(count: 100, title: String(repeating: "a", count: 512))
        let resources = Dictionary(uniqueKeysWithValues: candidates.map { ($0.mangaID, reference) })

        let plan = try ReadingPublicationPlan(projection: Self.projection(candidates), coverResourceIDs: resources)

        #expect(plan.items.map(\.mangaID) == Array(Int64(1)...54))
        #expect(plan.items.allSatisfy { $0.coverResourceID == nil })
        #expect(plan.totalEligibleCount == 100)
    }

    @Test(
        arguments: [
            (0, Optional<Int>.none, ReadingSnapshotError.invalidReadingVolume),
            (301, nil, .invalidReadingVolume),
            (2, 1, .invalidTotalVolumes),
            (1, 0, .invalidTotalVolumes),
            (1, 301, .invalidTotalVolumes)
        ]
    )
    func `rejects invalid reading data beyond the otherwise publishable prefix`(
        _ reading: Int,
        _ total: Int?,
        _ expectedError: ReadingSnapshotError
    ) {
        let candidates = Self.candidates(count: 100, title: String(repeating: "a", count: 512))
            + [
                Self.candidate(
                    mangaID: 101,
                    title: "Invalid trailing reading",
                    readingVolume: reading,
                    totalVolumes: total
                )
            ]

        #expect(throws: expectedError) {
            try ReadingPublicationPlan(projection: Self.projection(candidates))
        }
    }

    @Test(arguments: ["", " Unprepared", String(repeating: "a", count: 513)])
    func `rejects unprepared titles even after the transport prefix is full`(_ title: String) {
        let candidates = Self.candidates(count: 100, title: String(repeating: "a", count: 512))
            + [Self.candidate(mangaID: 101, title: title)]

        #expect(throws: ReadingSnapshotError.invalidTitle) {
            try ReadingPublicationPlan(projection: Self.projection(candidates))
        }
    }

    @Test
    func `rejects duplicate identities beyond the otherwise publishable prefix`() {
        let candidates = Self.candidates(count: 100, title: String(repeating: "a", count: 512))
            + [Self.candidate(mangaID: 1, title: "Duplicate trailing reading")]

        #expect(throws: ReadingSnapshotError.duplicateMangaID) {
            try ReadingPublicationPlan(projection: Self.projection(candidates))
        }
    }

    @Test
    func `an actually empty projection can prepare an empty publication`() throws {
        let plan = try ReadingPublicationPlan(projection: Self.projection([]))

        #expect(plan.items.isEmpty)
        #expect(plan.totalEligibleCount == 0)
    }

    @Test
    func `cancellation prevents returning a partial publication plan`() async {
        let candidates = Self.candidates(count: 100, title: String(repeating: "a", count: 512))

        await #expect(throws: CancellationError.self) {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.cancelAll()
                group.addTask {
                    _ = try ReadingPublicationPlan(projection: Self.projection(candidates))
                }
                try await group.waitForAll()
            }
        }
    }
}

private extension ReadingPublicationPlanTests {
    static let authority = SessionAuthority(
        userID: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
        generation: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2))
    )
    static let digest = String(repeating: "a", count: 64)

    static func projection(_ items: [CollectionReadingProjection.Item]) -> CollectionReadingProjection {
        CollectionReadingProjection(authority: authority, items: items)
    }

    static func candidates(
        count: Int,
        title: String? = nil,
        coverURL: URL? = nil
    ) -> [CollectionReadingProjection.Item] {
        (1...count).map { candidate(mangaID: Int64($0), title: title, coverURL: coverURL) }
    }

    static func candidate(
        mangaID: Int64,
        title: String? = nil,
        readingVolume: Int = 1,
        totalVolumes: Int? = nil,
        coverURL: URL? = nil
    ) -> CollectionReadingProjection.Item {
        CollectionReadingProjection.Item(
            mangaID: mangaID,
            title: title,
            readingVolume: readingVolume,
            totalVolumes: totalVolumes,
            coverURL: coverURL
        )
    }

    // Independent wire oracle: contract literals, no production DTO or codec.
    static func oracleJSON(
        _ items: [CollectionReadingProjection.Item],
        total: Int64,
        cover: String? = nil,
        revision: UInt64 = .max
    ) throws -> Data {
        let coverValue = try cover.map { try oracleString($0) } ?? "null"
        let wireItems = try items.map { item in
            let titleValue = try item.title.map { try oracleString($0) } ?? "null"
            let totalValue = item.totalVolumes.map(String.init) ?? "null"
            return #"{"coverResourceID":\#(coverValue),"mangaID":\#(item.mangaID),"#
                + #""readingVolume":\#(item.readingVolume),"title":\#(titleValue),"totalVolumes":\#(totalValue)}"#
        }.joined(separator: ",")
        let envelope = #"{"formatVersion":1,"generatedAt":"2026-09-06T00:00:00.000Z","items":[\#(wireItems)],"#
            + #""publicationGeneration":"11111111-1111-4111-8111-111111111111","revision":\#(revision),"#
            + #""sessionGeneration":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","state":"content","#
            + #""totalEligibleCount":\#(total)}"#
        return Data(envelope.utf8)
    }

    static func oracleString(_ value: String) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    static func oracleContext(
        _ items: [CollectionReadingProjection.Item],
        total: Int64,
        cover: String? = nil,
        revision: UInt64 = .max
    ) throws -> Int {
        let data = try oracleJSON(
            items,
            total: total,
            cover: cover,
            revision: revision
        )
        return try PropertyListSerialization.data(
            fromPropertyList: ["readingSnapshot": data],
            format: .binary,
            options: 0
        ).count
    }
}
