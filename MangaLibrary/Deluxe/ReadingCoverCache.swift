import CryptoKit
import Foundation

/// Reuses validated JPEGs for identical source bytes within one publication pipeline.
///
/// The caller still loads each URL and validates its event before supplying bytes. Only the
/// source digest and prepared JPEG are retained; failed sources are never cached. Least recently
/// used entries are evicted at two MiB or 128 entries, independently of the batch's eight MiB.
/// This actor owns synchronous hashing and Image I/O away from the main actor. Cancellation is
/// checked before changing retention, including on a hit; publication authority stays with the caller.
actor ReadingCoverCache {
    private static let maximumByteCount = 2_097_152
    private static let maximumEntryCount = 128

    struct Entry {
        let sourceDigest: SHA256.Digest
        let resource: ReadingCoverResource
    }

    private(set) var entries: [Entry] = []
    private(set) var retainedByteCount = 0

    func prepare(_ source: Data) throws -> ReadingCoverResource? {
        try Task.checkCancellation()
        guard !source.isEmpty, source.count <= ReadingCoverPreparation.maximumSourceByteCount else { return nil }
        let digest = SHA256.hash(data: source)
        try Task.checkCancellation()
        if let index = entries.firstIndex(where: { $0.sourceDigest == digest }) {
            let entry = entries.remove(at: index)
            entries.append(entry)
            return entry.resource
        }
        guard let resource = try ReadingCoverPreparation.prepare(source) else { return nil }
        try Task.checkCancellation()
        while entries.count >= Self.maximumEntryCount
            || resource.data.count > Self.maximumByteCount - retainedByteCount {
            retainedByteCount -= entries.removeFirst().resource.data.count
        }
        entries.append(Entry(sourceDigest: digest, resource: resource))
        retainedByteCount += resource.data.count
        return resource
    }
}
