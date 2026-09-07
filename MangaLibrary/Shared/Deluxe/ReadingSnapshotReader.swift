import Foundation

enum ReadingSnapshotReadResult: Equatable {
    case snapshot(ReadingSnapshot)
    case redacted
    case unavailable
}

/// Reads only a snapshot permitted by an unchanged fence around the envelope read.
struct ReadingSnapshotReader {
    let readFence: @Sendable () throws -> Data?
    let readSnapshot: @Sendable () throws -> Data?

    /// Distinguishes a verified closed fence from an unreadable or unauthorized observation.
    ///
    /// All three file effects run in order before interpreting the bytes, and their errors propagate.
    /// A stable closed fence redacts any residual envelope without decoding or exposing its content.
    func readResult() throws -> ReadingSnapshotReadResult {
        let first = try readFence()
        let data = try readSnapshot()
        let last = try readFence()
        guard let first, let last, first == last else { return .unavailable }
        do {
            let fence = try ReadingSnapshotCodec.decodeFence(first)
            guard let allowed = fence.allowedSessionGeneration else { return .redacted }
            guard let data else { return .unavailable }
            let snapshot = try ReadingSnapshotCodec.decode(data)
            guard
                snapshot.publicationGeneration == fence.publicationGeneration,
                snapshot.sessionGeneration == allowed,
                snapshot.state == .content || snapshot.state == .empty
            else { return .unavailable }
            return .snapshot(snapshot)
        } catch {
            return .unavailable
        }
    }

    /// Returns no content for malformed or denied bytes; propagates failures from the supplied file effects.
    func read() throws -> ReadingSnapshot? {
        switch try readResult() {
        case let .snapshot(snapshot):
            return snapshot
        case .redacted, .unavailable:
            return nil
        }
    }
}

enum CollectionWidgetReadResult: Equatable {
    case snapshot(ReadingSnapshot, CollectionWidgetSnapshot)
    case redacted
    case unavailable
}

/// Authorizes the complete collection only after materializing its verified slot behind a stable fence.
struct CollectionWidgetReader {
    let readFence: @Sendable () throws -> Data?
    let readSnapshot: @Sendable () throws -> Data?
    let readCollection: @Sendable (Int) throws -> Data?

    /// Rechecks denial after reading, hashing and decoding the referenced resource.
    ///
    /// Missing or malformed data produces no content. File errors propagate; a stable closed fence
    /// redacts residual bytes without opening a slot. A reused slot can fail verification but can
    /// never supply another revision's collection or a cached fallback.
    func readResult() throws -> CollectionWidgetReadResult {
        let first = try readFence()
        let manifest = try readSnapshot()
        let candidate = try readAuthorizedCollection(fenceData: first, snapshotData: manifest)
        let last = try readFence()
        guard let first, let last, first == last else { return .unavailable }
        return candidate
    }

    private func readAuthorizedCollection(fenceData: Data?, snapshotData: Data?) throws -> CollectionWidgetReadResult {
        guard let fenceData, let fence = try? ReadingSnapshotCodec.decodeFence(fenceData) else { return .unavailable }
        guard let allowed = fence.allowedSessionGeneration else { return .redacted }
        guard
            let snapshotData,
            let snapshot = try? ReadingSnapshotCodec.decode(snapshotData),
            snapshot.publicationGeneration == fence.publicationGeneration,
            snapshot.sessionGeneration == allowed,
            snapshot.state == .content || snapshot.state == .empty,
            let reference = snapshot.collectionReference
        else { return .unavailable }
        guard
            let data = try readCollection(reference.slot),
            CollectionWidgetSnapshotCodec.matches(data, reference: reference),
            let collection = try? CollectionWidgetSnapshotCodec.decode(data)
        else { return .unavailable }
        return .snapshot(snapshot, collection)
    }
}
