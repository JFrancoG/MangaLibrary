//
//  CollectionVolumePolicy.swift
//  MangaLibrary
//

import Foundation

/// The bounded volume-number domain shared by catalog and Collection.
///
/// A missing editorial total remains valid and means unknown. Every concrete
/// active total, owned volume and reading volume must remain inside
/// ``supportedRange`` before code derives a complete range, persists an edit or
/// builds a POST. An explicit bodyless DELETE may preserve incompatible legacy
/// values only inside an opaque tombstone; it never serializes them.
enum CollectionVolumePolicy {
    static let maximum: Int64 = 300
    static let supportedRange: ClosedRange<Int64> = 1...maximum

    static func contains(_ volume: Int64) -> Bool { supportedRange.contains(volume) }

    static func supportedKnownTotal(_ total: Int64?) -> Int64? {
        guard let total, contains(total) else { return nil }

        return total
    }

    static func completeVolumes(for total: Int64?) -> [Int64]? {
        guard let total, contains(total) else { return nil }

        return Array(1...total)
    }
}
