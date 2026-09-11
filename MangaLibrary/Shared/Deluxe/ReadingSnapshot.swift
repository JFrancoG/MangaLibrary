//
//  ReadingSnapshot.swift
//  MangaLibrary
//

import Foundation

/// A validated reading projection whose content still requires permission from a stable session fence.
///
/// Initializers and decoding enforce the same invariants. Dates retain the wire's millisecond precision;
/// publication ordering depends on generations and revisions, never on the timestamp.
/// An optional collection reference binds exact local slot bytes; consumers must validate that
/// resource inside the same fence observation before presenting collection content.
struct ReadingSnapshot: Codable, Equatable {
    enum State: String, Codable {
        case content
        case empty
        case redacted
        case unavailable
    }

    /// A prepared title and reading position; an unsafe cover reference degrades to a placeholder.
    ///
    /// Title abbreviation belongs to the publisher's projection. This boundary rejects unprepared titles
    /// instead of silently changing the published prefix or its order.
    struct Item: Codable, Equatable {
        let mangaID: Int64
        let title: String?
        let readingVolume: Int
        let totalVolumes: Int?
        let coverResourceID: String?

        init(
            mangaID: Int64,
            title: String?,
            readingVolume: Int,
            totalVolumes: Int?,
            coverResourceID: String?
        ) throws {
            guard (1...300).contains(readingVolume) else { throw ReadingSnapshotError.invalidReadingVolume }
            if let totalVolumes {
                guard (readingVolume...300).contains(totalVolumes) else {
                    throw ReadingSnapshotError.invalidTotalVolumes
                }
            }
            if let title {
                guard
                    !title.isEmpty,
                    title.utf8.count <= 512,
                    title == title.trimmingCharacters(in: .whitespacesAndNewlines)
                else {
                    throw ReadingSnapshotError.invalidTitle
                }
            }
            self.mangaID = mangaID
            self.title = title
            self.readingVolume = readingVolume
            self.totalVolumes = totalVolumes
            self.coverResourceID = coverResourceID.flatMap { reference in
                guard reference.utf8.count == 64 else { return nil }
                guard reference.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
                    return nil
                }
                return reference
            }
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            try self.init(
                mangaID: container.decode(Int64.self, forKey: .mangaID),
                title: container.decode(String?.self, forKey: .title),
                readingVolume: container.decode(Int.self, forKey: .readingVolume),
                totalVolumes: container.decode(Int?.self, forKey: .totalVolumes),
                coverResourceID: container.decode(String?.self, forKey: .coverResourceID)
            )
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(mangaID, forKey: .mangaID)
            try container.encode(title, forKey: .title)
            try container.encode(readingVolume, forKey: .readingVolume)
            try container.encode(totalVolumes, forKey: .totalVolumes)
            try container.encode(coverResourceID, forKey: .coverResourceID)
        }

        private enum CodingKeys: String, CodingKey {
            case mangaID
            case title
            case readingVolume
            case totalVolumes
            case coverResourceID
        }
    }

    let formatVersion = 1
    let publicationGeneration: UUID
    let revision: UInt64
    let sessionGeneration: UUID?
    let state: State
    let generatedAt: Date
    let totalEligibleCount: Int64?
    let items: [Item]
    let preferredStartMangaID: Int64?
    let collectionReference: CollectionWidgetSnapshot.Reference?

    init(
        publicationGeneration: UUID,
        revision: UInt64,
        sessionGeneration: UUID?,
        state: State,
        generatedAt: Date,
        totalEligibleCount: Int64?,
        items: [Item],
        preferredStartMangaID: Int64? = nil,
        collectionReference: CollectionWidgetSnapshot.Reference? = nil
    ) throws {
        guard revision > 0 else { throw ReadingSnapshotError.invalidRevision }
        switch state {
        case .content:
            guard sessionGeneration != nil, !items.isEmpty else { throw ReadingSnapshotError.invalidState }
            guard let totalEligibleCount, totalEligibleCount >= Int64(items.count) else {
                throw ReadingSnapshotError.invalidCount
            }
        case .empty:
            guard sessionGeneration != nil, items.isEmpty else { throw ReadingSnapshotError.invalidState }
            guard totalEligibleCount == 0 else { throw ReadingSnapshotError.invalidCount }
        case .redacted:
            guard sessionGeneration != nil, items.isEmpty else { throw ReadingSnapshotError.invalidState }
            guard totalEligibleCount == nil else { throw ReadingSnapshotError.invalidCount }
        case .unavailable:
            guard items.isEmpty else { throw ReadingSnapshotError.invalidState }
            guard totalEligibleCount == nil else { throw ReadingSnapshotError.invalidCount }
        }
        guard Set(items.map(\.mangaID)).count == items.count else { throw ReadingSnapshotError.duplicateMangaID }
        if let preferredStartMangaID {
            guard items.contains(where: { $0.mangaID == preferredStartMangaID }) else {
                throw ReadingSnapshotError.invalidPreferredStartMangaID
            }
        }
        guard collectionReference == nil || state == .content || state == .empty else {
            throw ReadingSnapshotError.invalidState
        }
        let timestamp = try ReadingSnapshotTimestamp.string(from: generatedAt)
        self.publicationGeneration = publicationGeneration
        self.revision = revision
        self.sessionGeneration = sessionGeneration
        self.state = state
        self.generatedAt = try ReadingSnapshotTimestamp.date(from: timestamp)
        self.totalEligibleCount = totalEligibleCount
        self.items = items
        self.preferredStartMangaID = preferredStartMangaID
        self.collectionReference = collectionReference
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard try container.decode(Int.self, forKey: .formatVersion) == 1 else {
            throw ReadingSnapshotError.unsupportedFormat
        }
        let timestamp = try container.decode(String.self, forKey: .generatedAt)
        let collection = try container.decodeIfPresent(
            CollectionWidgetSnapshot.Reference.self,
            forKey: .collectionReference
        )
        try self.init(
            publicationGeneration: container.decode(UUID.self, forKey: .publicationGeneration),
            revision: container.decode(UInt64.self, forKey: .revision),
            sessionGeneration: container.decode(UUID?.self, forKey: .sessionGeneration),
            state: container.decode(State.self, forKey: .state),
            generatedAt: ReadingSnapshotTimestamp.date(from: timestamp),
            totalEligibleCount: container.decode(Int64?.self, forKey: .totalEligibleCount),
            items: container.decode([Item].self, forKey: .items),
            preferredStartMangaID: container.decodeIfPresent(Int64.self, forKey: .preferredStartMangaID),
            collectionReference: collection
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(formatVersion, forKey: .formatVersion)
        try container.encode(publicationGeneration, forKey: .publicationGeneration)
        try container.encode(revision, forKey: .revision)
        try container.encode(sessionGeneration, forKey: .sessionGeneration)
        try container.encode(state, forKey: .state)
        try container.encode(ReadingSnapshotTimestamp.string(from: generatedAt), forKey: .generatedAt)
        try container.encode(totalEligibleCount, forKey: .totalEligibleCount)
        try container.encode(items, forKey: .items)
        try container.encodeIfPresent(preferredStartMangaID, forKey: .preferredStartMangaID)
        try container.encodeIfPresent(collectionReference, forKey: .collectionReference)
    }

    private enum CodingKeys: String, CodingKey {
        case formatVersion
        case publicationGeneration
        case revision
        case sessionGeneration
        case state
        case generatedAt
        case totalEligibleCount
        case items
        case preferredStartMangaID
        case collectionReference
    }
}

enum ReadingSnapshotError: Error, Equatable {
    case unsupportedFormat
    case invalidRevision
    case invalidState
    case invalidCount
    case duplicateMangaID
    case invalidPreferredStartMangaID
    case invalidTitle
    case invalidReadingVolume
    case invalidTotalVolumes
    case invalidDate
    case invalidUTF8
    case payloadTooLarge
}

private enum ReadingSnapshotTimestamp {
    static let format = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    static let wholeSecondFormat = Date.ISO8601FormatStyle(includingFractionalSeconds: false)

    static func string(from date: Date) throws -> String {
        let seconds = date.timeIntervalSince1970
        guard seconds.isFinite, (-62_167_219_200.0..<253_402_300_800.0).contains(seconds) else {
            throw ReadingSnapshotError.invalidDate
        }
        // Keep calendar formatting separate from binary submillisecond precision.
        // Round within the current second, including before 1970; never carry into the next second.
        let wholeSeconds = seconds.rounded(.down)
        let milliseconds = min(Int(((seconds - wholeSeconds) * 1_000).rounded()), 999)
        let digits = String(milliseconds)
        let fraction = String(repeating: "0", count: 3 - digits.count) + digits
        let whole = wholeSecondFormat.format(Date(timeIntervalSince1970: wholeSeconds))
        let value = String(whole.dropLast()) + ".\(fraction)Z"
        guard value.utf8.count == 24, value.hasSuffix("Z") else { throw ReadingSnapshotError.invalidDate }
        return value
    }

    static func date(from value: String) throws -> Date {
        guard value.utf8.count == 24, value.hasSuffix("Z") else { throw ReadingSnapshotError.invalidDate }
        guard let date = try? format.parse(value), try string(from: date) == value else {
            throw ReadingSnapshotError.invalidDate
        }
        return date
    }
}

/// The complete active collection, stored separately from the bounded reading envelope.
struct CollectionWidgetSnapshot: Codable, Equatable {
    struct Item: Codable, Equatable {
        let mangaID: Int64
        private let preparedTitle: String?
        let ownedVolumeCount: Int
        let totalVolumes: Int?
        let isComplete: Bool
        let coverResourceID: String?

        var title: String? { preparedTitle }

        private enum CodingKeys: String, CodingKey {
            case mangaID, title, ownedVolumeCount, totalVolumes, isComplete, coverResourceID
        }
    }

    /// Identifies one reusable slot by the exact bytes authorized by the reading envelope.
    struct Reference: Codable, Equatable {
        private let selectedSlot: Int
        let digest: String
        let byteCount: Int

        var slot: Int { selectedSlot }

        private enum CodingKeys: String, CodingKey { case slot, digest, byteCount }
    }

    let formatVersion = 1
    private let collectionItems: [Item]
    let preferredStartMangaID: Int64?

    var items: [Item] { collectionItems }

    private enum CodingKeys: String, CodingKey { case formatVersion, items, preferredStartMangaID }
}

extension CollectionWidgetSnapshot.Item {
    init(
        mangaID: Int64,
        title: String?,
        ownedVolumeCount: Int,
        totalVolumes: Int?,
        isComplete: Bool,
        coverResourceID: String? = nil
    ) throws {
        guard mangaID > 0 else { throw CollectionWidgetSnapshotError.invalidMangaID }
        guard (0...300).contains(ownedVolumeCount) else { throw CollectionWidgetSnapshotError.invalidOwnedVolumeCount }
        if let totalVolumes {
            guard (1...300).contains(totalVolumes), ownedVolumeCount <= totalVolumes else {
                throw CollectionWidgetSnapshotError.invalidTotalVolumes
            }
        }
        if isComplete {
            guard let totalVolumes, ownedVolumeCount == totalVolumes else {
                throw CollectionWidgetSnapshotError.invalidCompleteness
            }
        }
        if let title {
            guard
                !title.isEmpty,
                title.utf8.count <= 512,
                title == title.trimmingCharacters(in: .whitespacesAndNewlines)
            else { throw CollectionWidgetSnapshotError.invalidTitle }
        }
        self.mangaID = mangaID
        preparedTitle = title
        self.ownedVolumeCount = ownedVolumeCount
        self.totalVolumes = totalVolumes
        self.isComplete = isComplete
        self.coverResourceID = coverResourceID.flatMap { reference in
            guard
                reference.utf8.count == 64,
                reference.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) })
            else { return nil }
            return reference
        }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            mangaID: container.decode(Int64.self, forKey: .mangaID),
            title: container.decode(String?.self, forKey: .title),
            ownedVolumeCount: container.decode(Int.self, forKey: .ownedVolumeCount),
            totalVolumes: container.decode(Int?.self, forKey: .totalVolumes),
            isComplete: container.decode(Bool.self, forKey: .isComplete),
            coverResourceID: container.decodeIfPresent(String.self, forKey: .coverResourceID)
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mangaID, forKey: .mangaID)
        try container.encode(title, forKey: .title)
        try container.encode(ownedVolumeCount, forKey: .ownedVolumeCount)
        try container.encode(totalVolumes, forKey: .totalVolumes)
        try container.encode(isComplete, forKey: .isComplete)
        try container.encode(coverResourceID, forKey: .coverResourceID)
    }
}

extension CollectionWidgetSnapshot.Reference {
    init(slot: Int, digest: String, byteCount: Int) throws {
        guard
            (0...1).contains(slot),
            (1...CollectionWidgetSnapshotCodec.maximumByteCount).contains(byteCount),
            digest.utf8.count == 64,
            digest.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) })
        else { throw CollectionWidgetSnapshotError.invalidReference }
        selectedSlot = slot
        self.digest = digest
        self.byteCount = byteCount
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            slot: container.decode(Int.self, forKey: .slot),
            digest: container.decode(String.self, forKey: .digest),
            byteCount: container.decode(Int.self, forKey: .byteCount)
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(slot, forKey: .slot)
        try container.encode(digest, forKey: .digest)
        try container.encode(byteCount, forKey: .byteCount)
    }
}

extension CollectionWidgetSnapshot {
    init(items: [Item], preferredStartMangaID: Int64? = nil) throws {
        guard items.count <= CollectionWidgetSnapshotCodec.maximumItemCount else {
            throw CollectionWidgetSnapshotError.tooManyItems
        }
        guard Set(items.map(\.mangaID)).count == items.count else {
            throw CollectionWidgetSnapshotError.duplicateMangaID
        }
        if let preferredStartMangaID, !items.contains(where: { $0.mangaID == preferredStartMangaID }) {
            throw CollectionWidgetSnapshotError.invalidPreferredMangaID
        }
        collectionItems = items
        self.preferredStartMangaID = preferredStartMangaID
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard try container.decode(Int.self, forKey: .formatVersion) == 1 else {
            throw CollectionWidgetSnapshotError.unsupportedFormat
        }
        try self.init(
            items: container.decode([Item].self, forKey: .items),
            preferredStartMangaID: container.decodeIfPresent(Int64.self, forKey: .preferredStartMangaID)
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(formatVersion, forKey: .formatVersion)
        try container.encode(items, forKey: .items)
        try container.encodeIfPresent(preferredStartMangaID, forKey: .preferredStartMangaID)
    }
}

enum CollectionWidgetSnapshotError: Error, Equatable {
    case unsupportedFormat
    case invalidMangaID
    case invalidPreferredMangaID
    case invalidTitle
    case invalidOwnedVolumeCount
    case invalidTotalVolumes
    case invalidCompleteness
    case duplicateMangaID
    case tooManyItems
    case invalidReference
    case payloadTooLarge
    case invalidUTF8
}
