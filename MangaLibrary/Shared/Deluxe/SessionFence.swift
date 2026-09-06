//
//  SessionFence.swift
//  MangaLibrary
//

import Foundation

/// Permission for one publication epoch and session, denied when the allowed session is absent.
///
/// A reader must observe the same fence before and after reading the envelope. A single valid fence
/// or a readable envelope alone cannot authorize presentation.
struct SessionFence: Codable, Equatable {
    let formatVersion = 1
    let publicationGeneration: UUID
    let fenceRevision: UInt64
    let allowedSessionGeneration: UUID?

    init(publicationGeneration: UUID, fenceRevision: UInt64, allowedSessionGeneration: UUID?) throws {
        guard fenceRevision > 0 else { throw ReadingSnapshotError.invalidRevision }
        self.publicationGeneration = publicationGeneration
        self.fenceRevision = fenceRevision
        self.allowedSessionGeneration = allowedSessionGeneration
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard try container.decode(Int.self, forKey: .formatVersion) == 1 else {
            throw ReadingSnapshotError.unsupportedFormat
        }
        try self.init(
            publicationGeneration: container.decode(UUID.self, forKey: .publicationGeneration),
            fenceRevision: container.decode(UInt64.self, forKey: .fenceRevision),
            allowedSessionGeneration: container.decode(UUID?.self, forKey: .allowedSessionGeneration)
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(formatVersion, forKey: .formatVersion)
        try container.encode(publicationGeneration, forKey: .publicationGeneration)
        try container.encode(fenceRevision, forKey: .fenceRevision)
        try container.encode(allowedSessionGeneration, forKey: .allowedSessionGeneration)
    }

    private enum CodingKeys: String, CodingKey {
        case formatVersion
        case publicationGeneration
        case fenceRevision
        case allowedSessionGeneration
    }
}
