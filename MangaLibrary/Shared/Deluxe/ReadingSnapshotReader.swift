import Foundation

/// Reads only a snapshot permitted by an unchanged fence around the envelope read.
struct ReadingSnapshotReader {
    let readFence: @Sendable () throws -> Data?
    let readSnapshot: @Sendable () throws -> Data?

    /// Returns no content for malformed or denied bytes; propagates failures from the supplied file effects.
    func read() throws -> ReadingSnapshot? {
        let first = try readFence()
        let data = try readSnapshot()
        let last = try readFence()
        guard let first, let data, let last, first == last else { return nil }
        do {
            let fence = try ReadingSnapshotCodec.decodeFence(first)
            let snapshot = try ReadingSnapshotCodec.decode(data)
            guard
                let allowed = fence.allowedSessionGeneration,
                snapshot.publicationGeneration == fence.publicationGeneration,
                snapshot.sessionGeneration == allowed,
                snapshot.state == .content || snapshot.state == .empty
            else { return nil }
            return snapshot
        } catch {
            return nil
        }
    }
}
