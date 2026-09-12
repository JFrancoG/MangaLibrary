import Foundation

enum WatchReadingSnapshotState: Equatable {
    case unavailable
    case snapshot(ReadingSnapshot)
}

/// Serializes received contexts and retains a bounded, compatible reading projection.
///
/// The caller preserves WatchConnectivity's delivery order. Revisions order only one publication
/// epoch; retired opaque generations prevent replays from restoring a removed projection. The single
/// 64 KiB cache includes these barriers. Exhaustion persists an unavailable state without dropping
/// barriers or guessing a time to expire them. This cache neither authenticates nor expires a session.
actor WatchReadingSnapshotReceiver {
    private let storage: WatchReadingSnapshotStorage
    private var cache = WatchReadingSnapshotCache()
    private var pendingWrite: (context: Data, cache: WatchReadingSnapshotCache)?
    private var restored = false

    init(storage: WatchReadingSnapshotStorage) {
        self.storage = storage
    }

    /// Reads once per receiver lifetime. An inaccessible cache cannot authorize a fresh ordering history.
    func restore() -> WatchReadingSnapshotState {
        guard !restored else { return state }
        do {
            if let data = try storage.read() {
                do {
                    guard data.count <= WatchReadingSnapshotStorage.maximumByteCount else {
                        throw WatchReadingSnapshotStorageError.incompatible
                    }
                    cache = try JSONDecoder().decode(WatchReadingSnapshotCache.self, from: data)
                } catch {
                    try discardAndVerify()
                }
            }
            restored = true
        } catch WatchReadingSnapshotStorageError.incompatible {
            do {
                try discardAndVerify()
                restored = true
            } catch {
                return .unavailable
            }
        } catch {
            return .unavailable
        }
        return state
    }

    /// Accepts one complete context without suspending between validation, ordering and cache effects.
    ///
    /// A failed cache write hides the projection and removes and verifies the preceding file. If all
    /// writes and removal are inaccessible, durable retirement cannot be claimed; the caller must
    /// reconcile WCSession's most recently received context before presenting a cache on reactivation.
    /// This instance can retry the exact bytes of its last failed candidate, showing it only after
    /// verified persistence. A new accepted transition, incompatible input or saturation supersedes
    /// that candidate; durable duplicates and other bytes with the same revision remain ignored.
    func receive(_ data: Data) -> WatchReadingSnapshotState {
        _ = restore()
        guard restored, !cache.saturated else { return .unavailable }
        let snapshot: ReadingSnapshot
        do {
            snapshot = try ReadingSnapshotCodec.decode(data)
            guard try ReadingSnapshotCodec.contextByteCount(for: data) <= ReadingSnapshotCodec.maximumContextByteCount else {
                throw WatchReadingSnapshotStorageError.incompatible
            }
        } catch {
            var unavailable = cache
            unavailable.snapshot = nil
            return commit(unavailable)
        }

        if let pendingWrite, pendingWrite.context == data {
            return commit(pendingWrite.cache, context: data)
        }

        guard !cache.retiredEpochs.contains(snapshot.publicationGeneration) else { return state }
        if snapshot.publicationGeneration == cache.epoch {
            guard snapshot.revision > cache.revision else { return state }
        }
        if snapshot.state == .content || snapshot.state == .empty {
            guard let session = snapshot.sessionGeneration else { return state }
            guard !cache.retiredSessions.contains(session) else { return state }
        }

        var proposed = cache
        if
            snapshot.state == .redacted,
            let session = snapshot.sessionGeneration,
            let current = cache.session,
            session != current
        {
            // An unrelated redaction supplies a retirement barrier, never a replacement display.
            proposed.retire(session: session)
            if snapshot.publicationGeneration == proposed.epoch {
                proposed.revision = max(proposed.revision, snapshot.revision)
            }
            guard proposed != cache else { return state }
            return commit(proposed, context: data)
        }
        if snapshot.publicationGeneration != cache.epoch {
            if let previous = cache.epoch {
                proposed.retiredEpochs.append(previous)
            }
            proposed.epoch = snapshot.publicationGeneration
            proposed.revision = 0
        }

        if let previous = cache.session, let next = snapshot.sessionGeneration, previous != next {
            proposed.retire(session: previous)
        }
        if snapshot.state == .redacted, let session = snapshot.sessionGeneration {
            proposed.retire(session: session)
        }
        proposed.session = snapshot.sessionGeneration ?? proposed.session
        proposed.revision = snapshot.revision
        proposed.snapshot = snapshot
        return commit(proposed, context: data)
    }

    private var state: WatchReadingSnapshotState {
        cache.snapshot.map(WatchReadingSnapshotState.snapshot) ?? .unavailable
    }

    private func commit(_ proposed: WatchReadingSnapshotCache, context: Data? = nil) -> WatchReadingSnapshotState {
        pendingWrite = nil
        var next = proposed
        let data: Data
        do {
            let candidate = try encode(next)
            if candidate.count <= WatchReadingSnapshotStorage.maximumByteCount {
                data = candidate
            } else {
                // The incoming transition was never accepted. Keep all existing barriers and stop
                // accepting contexts instead of evicting history that could permit a replay.
                next = cache
                next.snapshot = nil
                next.saturated = true
                data = try encode(next)
                guard data.count <= WatchReadingSnapshotStorage.maximumByteCount else {
                    throw WatchReadingSnapshotStorageError.incompatible
                }
            }
            cache = next
            try storage.replace(data)
            guard try storage.read() == data else { throw WatchReadingSnapshotStorageError.unavailable }
        } catch {
            cache = next
            cache.snapshot = nil
            if let context, !next.saturated {
                // Retain the complete proposed transition, including retirement barriers, for this instance only.
                pendingWrite = (context, next)
            }
            do {
                try discardAndVerify()
            } catch {
                // No in-process path restores the residual content after a failed retirement.
            }
        }
        return state
    }

    private func encode(_ value: WatchReadingSnapshotCache) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    private func discardAndVerify() throws {
        try storage.discard()
        guard try storage.read() == nil else { throw WatchReadingSnapshotStorageError.unavailable }
    }
}

/// Private acceptance metadata and visible content form a single atomically replaced cache.
private struct WatchReadingSnapshotCache: Codable, Equatable {
    let formatVersion = 1
    var epoch: UUID?
    var session: UUID?
    var revision: UInt64 = 0
    var snapshot: ReadingSnapshot?
    var retiredEpochs: [UUID] = []
    var retiredSessions: [UUID] = []
    var saturated = false

    mutating func retire(session: UUID) {
        if !retiredSessions.contains(session) {
            retiredSessions.append(session)
        }
    }
}

private extension WatchReadingSnapshotCache {
    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard try values.decode(Int.self, forKey: .formatVersion) == 1 else {
            throw WatchReadingSnapshotStorageError.incompatible
        }
        epoch = try values.decodeIfPresent(UUID.self, forKey: .epoch)
        session = try values.decodeIfPresent(UUID.self, forKey: .session)
        revision = try values.decode(UInt64.self, forKey: .revision)
        snapshot = try values.decodeIfPresent(ReadingSnapshot.self, forKey: .snapshot)
        retiredEpochs = try values.decode([UUID].self, forKey: .retiredEpochs)
        retiredSessions = try values.decode([UUID].self, forKey: .retiredSessions)
        saturated = try values.decode(Bool.self, forKey: .saturated)
        guard
            Set(retiredEpochs).count == retiredEpochs.count,
            Set(retiredSessions).count == retiredSessions.count,
            epoch.map({ !retiredEpochs.contains($0) }) ?? (revision == 0),
            !saturated || snapshot == nil
        else {
            throw WatchReadingSnapshotStorageError.incompatible
        }
        if let snapshot {
            guard snapshot.publicationGeneration == epoch, snapshot.revision <= revision else {
                throw WatchReadingSnapshotStorageError.incompatible
            }
            if snapshot.state == .content || snapshot.state == .empty {
                guard let snapshotSession = snapshot.sessionGeneration else {
                    throw WatchReadingSnapshotStorageError.incompatible
                }
                guard snapshotSession == session, !retiredSessions.contains(snapshotSession) else {
                    throw WatchReadingSnapshotStorageError.incompatible
                }
            }
            if snapshot.state == .redacted {
                guard let snapshotSession = snapshot.sessionGeneration, retiredSessions.contains(snapshotSession) else {
                    throw WatchReadingSnapshotStorageError.incompatible
                }
            }
        }
    }
}
