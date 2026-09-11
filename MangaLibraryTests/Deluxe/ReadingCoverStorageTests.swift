import Darwin
import Foundation
import ImageIO
import Synchronization
import Testing
import UniformTypeIdentifiers
@testable import MangaLibrary

@Suite("Durable cover admission", .tags(.integration))
struct ReadingCoverStorageTests {
    @Test
    func `admission deduplicates in candidate order without writing`() throws {
        let harness = try Harness()
        defer { harness.remove() }
        let first = try resource(40)
        let second = try resource(200)
        let before = try harness.files()

        let admitted = try harness.storage().admissibleResources([second, first, second])

        #expect(admitted.map(\.identifier) == [second.identifier, first.identifier])
        #expect(try harness.files() == before)
    }

    @Test
    func `resources and retention precede the caller manifest commit`() throws {
        let harness = try Harness()
        defer { harness.remove() }
        let image = try resource(40)
        let events = Mutex<[String]>([])
        let live = ReadingCoverStorage.Effects.live
        let effects = ReadingCoverStorage.Effects(
            read: live.read,
            writeExclusive: { url, data in
                events.withLock {
                    $0.append(url.deletingLastPathComponent().lastPathComponent)
                }
                try live.writeExclusive(url, data)
            },
            promoteExclusive: { source, destination in
                events.withLock {
                    $0.append("promotion")
                }
                try live.promoteExclusive(source, destination)
            },
            remove: live.remove,
            inventory: live.inventory
        )
        try harness.storage(effects: effects).prepare(
            [image],
            attemptID: UUID(),
            previousManifest: Self.previousManifest,
            expectedManifest: Self.expectedManifest
        )

        #expect(events.withLock { $0 } == ["cover-admission", "staging", "promotion", "receipts"])
        #expect(try Data(contentsOf: harness.cover(image)) == image.data)
        #expect(try Data(contentsOf: harness.receipt(image)) == Self.receipt)
        #expect(ReadingCoverReader(sharedDirectory: harness.shared).read(image.identifier) == image)
        try harness.storage().recover(currentManifest: Self.expectedManifest)
        #expect(try Data(contentsOf: harness.cover(image)) == image.data)
        #expect(!FileManager.default.fileExists(atPath: harness.journal.path))
    }

    @Test
    func `quota includes receipts and journal before any image is admitted`() throws {
        let harness = try Harness()
        defer { harness.remove() }
        let image = try resource(40)
        try harness.fillQuota(leaving: image.data.count + Self.receipt.count)
        let before = try harness.files()

        #expect(try harness.storage().admissibleResources([image]).isEmpty)
        #expect(try harness.files() == before)
    }

    @Test
    func `full quota still reuses an intact retained image without another admission`() throws {
        let harness = try Harness()
        defer { harness.remove() }
        let image = try resource(40)
        let storage = try harness.storage()
        try storage.prepare(
            [image],
            attemptID: UUID(),
            previousManifest: Self.previousManifest,
            expectedManifest: Self.expectedManifest
        )
        try storage.recover(currentManifest: Self.expectedManifest)
        try harness.fillQuota(leaving: 0)
        let before = try harness.files()

        #expect(try storage.admissibleResources([image, image]) == [image])
        try storage.prepare(
            [image],
            attemptID: UUID(),
            previousManifest: Self.expectedManifest,
            expectedManifest: Data("another committed manifest".utf8)
        )
        #expect(try harness.files() == before)
    }

    @Test
    func `failure after the complete JPEG leaves a demonstrably reclaimable orphan`() throws {
        let harness = try Harness()
        defer { harness.remove() }
        let image = try resource(40)
        let failing = try harness.storage(effects: failingReceiptEffects())
        #expect(throws: StorageFailure.diskFull) {
            try failing.prepare(
                [image],
                attemptID: UUID(),
                previousManifest: Self.previousManifest,
                expectedManifest: Self.expectedManifest
            )
        }
        #expect(try Data(contentsOf: harness.cover(image)) == image.data)

        try harness.storage().recover(currentManifest: Self.previousManifest)

        #expect(!FileManager.default.fileExists(atPath: harness.cover(image).path))
        #expect(!FileManager.default.fileExists(atPath: harness.journal.path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: harness.staging.path).isEmpty)
    }

    @Test
    func `partial staging is never promoted and can be recovered without a receipt`() throws {
        let harness = try Harness()
        defer { harness.remove() }
        let image = try resource(40)
        let live = ReadingCoverStorage.Effects.live
        let effects = ReadingCoverStorage.Effects(
            read: live.read,
            writeExclusive: { url, data in
                if url.deletingLastPathComponent().lastPathComponent == "staging" {
                    try live.writeExclusive(url, Data(data.prefix(32)))
                    throw StorageFailure.diskFull
                }
                try live.writeExclusive(url, data)
            },
            promoteExclusive: live.promoteExclusive,
            remove: live.remove,
            inventory: live.inventory
        )
        #expect(throws: StorageFailure.diskFull) {
            try harness.storage(effects: effects).prepare(
                [image],
                attemptID: UUID(),
                previousManifest: Self.previousManifest,
                expectedManifest: Self.expectedManifest
            )
        }
        #expect(!FileManager.default.fileExists(atPath: harness.cover(image).path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: harness.staging.path).count == 1)

        try harness.storage().recover(currentManifest: Self.previousManifest)

        #expect(try FileManager.default.contentsOfDirectory(atPath: harness.staging.path).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: harness.journal.path))
    }

    @Test
    func `a retained receipt survives a failed manifest and a missing JPEG`() throws {
        let harness = try Harness()
        defer { harness.remove() }
        let image = try resource(40)
        let storage = try harness.storage()
        try storage.prepare(
            [image],
            attemptID: UUID(),
            previousManifest: Self.previousManifest,
            expectedManifest: Self.expectedManifest
        )
        try storage.recover(currentManifest: Self.previousManifest)
        #expect(try Data(contentsOf: harness.cover(image)) == image.data)
        try FileManager.default.removeItem(at: harness.cover(image))

        try storage.prepare(
            [image],
            attemptID: UUID(),
            previousManifest: Self.previousManifest,
            expectedManifest: Self.expectedManifest
        )
        try storage.recover(currentManifest: Self.previousManifest)

        #expect(try Data(contentsOf: harness.cover(image)) == image.data)
        #expect(try Data(contentsOf: harness.receipt(image)) == Self.receipt)
    }

    @Test
    func `a restored JPEG still referenced by the previous manifest cannot be reclaimed`() throws {
        let harness = try Harness()
        defer { harness.remove() }
        let image = try resource(40)
        let previous = try manifest(referencing: image.identifier)
        let storage = try harness.storage()
        try storage.prepare(
            [image],
            attemptID: UUID(),
            previousManifest: Self.previousManifest,
            expectedManifest: previous
        )
        try storage.recover(currentManifest: previous)
        try FileManager.default.removeItem(at: harness.cover(image))
        try FileManager.default.removeItem(at: harness.receipt(image))
        #expect(throws: StorageFailure.diskFull) {
            try harness.storage(effects: failingReceiptEffects()).prepare(
                [image],
                attemptID: UUID(),
                previousManifest: previous,
                expectedManifest: Self.expectedManifest
            )
        }

        try storage.recover(currentManifest: previous)

        #expect(try Data(contentsOf: harness.cover(image)) == image.data)
        #expect(ReadingCoverReader(sharedDirectory: harness.shared).read(image.identifier) == image)
    }

    @Test
    func `an incompatible predecessor cannot prove that an image was never published`() throws {
        let harness = try Harness()
        defer { harness.remove() }
        let image = try resource(40)
        let incompatible = Data("incompatible canonical manifest".utf8)
        #expect(throws: StorageFailure.diskFull) {
            try harness.storage(effects: failingReceiptEffects()).prepare(
                [image],
                attemptID: UUID(),
                previousManifest: incompatible,
                expectedManifest: Self.expectedManifest
            )
        }
        let before = try harness.files()

        #expect(throws: ReadingCoverStorageError.incompatibleStorage) {
            try harness.storage().recover(currentManifest: incompatible)
        }
        #expect(try harness.files() == before)
    }

    @Test
    func `an unrelated manifest makes an unfinished admission ambiguous`() throws {
        let harness = try Harness()
        defer { harness.remove() }
        let image = try resource(40)
        #expect(throws: StorageFailure.diskFull) {
            try harness.storage(effects: failingReceiptEffects()).prepare(
                [image],
                attemptID: UUID(),
                previousManifest: Self.previousManifest,
                expectedManifest: Self.expectedManifest
            )
        }
        let before = try harness.files()

        #expect(throws: ReadingCoverStorageError.unresolvedAdmission) {
            try harness.storage().recover(currentManifest: Data("unrelated manifest".utf8))
        }
        #expect(throws: ReadingCoverStorageError.unresolvedAdmission) {
            try harness.storage().admissibleResources([image])
        }
        #expect(try harness.files() == before)
    }

    @Test
    func `corrupt admission metadata cannot authorize deletion or further admission`() throws {
        let harness = try Harness()
        defer { harness.remove() }
        let image = try resource(40)
        try harness.storage().prepare(
            [image],
            attemptID: UUID(),
            previousManifest: Self.previousManifest,
            expectedManifest: Self.expectedManifest
        )
        try Data("{".utf8).write(to: harness.journal)
        let before = try harness.files()

        #expect(throws: (any Error).self) {
            try harness.storage().recover(currentManifest: Self.previousManifest)
        }
        #expect(throws: (any Error).self) {
            try harness.storage().admissibleResources([image])
        }
        #expect(try harness.files() == before)
    }

    @Test
    func `unavailable metadata is preserved without admitting new resources`() throws {
        let harness = try Harness()
        defer { harness.remove() }
        let image = try resource(40)
        let live = ReadingCoverStorage.Effects.live
        let effects = ReadingCoverStorage.Effects(
            read: { url, limit in
                if url.lastPathComponent == "journal.json" {
                    throw StorageFailure.locked
                }
                return try live.read(url, limit)
            },
            writeExclusive: live.writeExclusive,
            promoteExclusive: live.promoteExclusive,
            remove: live.remove,
            inventory: live.inventory
        )
        let before = try harness.files()

        #expect(throws: StorageFailure.locked) {
            try harness.storage(effects: effects).admissibleResources([image])
        }
        #expect(try harness.files() == before)
    }

    @Test
    func `unavailable inventory cannot authorize orphan deletion`() throws {
        let harness = try Harness()
        defer { harness.remove() }
        let image = try resource(40)
        #expect(throws: StorageFailure.diskFull) {
            try harness.storage(effects: failingReceiptEffects()).prepare(
                [image],
                attemptID: UUID(),
                previousManifest: Self.previousManifest,
                expectedManifest: Self.expectedManifest
            )
        }
        let live = ReadingCoverStorage.Effects.live
        let effects = ReadingCoverStorage.Effects(
            read: live.read,
            writeExclusive: live.writeExclusive,
            promoteExclusive: live.promoteExclusive,
            remove: live.remove,
            inventory: { _ in
                throw StorageFailure.locked
            }
        )
        let before = try harness.files()

        #expect(throws: StorageFailure.locked) {
            try harness.storage(effects: effects).recover(currentManifest: Self.previousManifest)
        }
        #expect(try harness.files() == before)
    }

    @Test
    func `all retention metadata is read before deleting any orphan`() throws {
        let harness = try Harness()
        defer { harness.remove() }
        let first = try resource(40)
        let second = try resource(200)
        #expect(throws: StorageFailure.diskFull) {
            try harness.storage(effects: failingReceiptEffects()).prepare(
                [first, second],
                attemptID: UUID(),
                previousManifest: Self.previousManifest,
                expectedManifest: Self.expectedManifest
            )
        }
        let unreadableReceipt = harness.receipt(second)
        let live = ReadingCoverStorage.Effects.live
        let effects = ReadingCoverStorage.Effects(
            read: { url, limit in
                if url == unreadableReceipt {
                    throw StorageFailure.locked
                }
                return try live.read(url, limit)
            },
            writeExclusive: live.writeExclusive,
            promoteExclusive: live.promoteExclusive,
            remove: live.remove,
            inventory: live.inventory
        )
        let before = try harness.files()

        #expect(throws: StorageFailure.locked) {
            try harness.storage(effects: effects).recover(currentManifest: Self.previousManifest)
        }
        #expect(try harness.files() == before)
    }

    @Test(arguments: InvalidFile.allCases)
    fileprivate func `reader rejects unsafe or incompatible local resources`(_ invalid: InvalidFile) throws {
        let harness = try Harness()
        defer { harness.remove() }
        let image = try resource(40)
        let destination = harness.cover(image)
        switch invalid {
        case .wrongDigest:
            try resource(200).data.write(to: destination)
        case .truncated:
            try Data(image.data.prefix(32)).write(to: destination)
        case .oversized:
            try Data(repeating: 0, count: 65_537).write(to: destination)
        case .symbolicLink:
            let outside = harness.directory.appending(path: "outside.jpg")
            try image.data.write(to: outside)
            try FileManager.default.createSymbolicLink(at: destination, withDestinationURL: outside)
        case .namedPipe:
            try #require(mkfifo(destination.path, 0o600) == 0)
        }

        #expect(ReadingCoverReader(sharedDirectory: harness.shared).read(image.identifier) == nil)
    }

    @Test
    func `a covers directory symlink cannot redirect readers or writers outside the root`() throws {
        let harness = try Harness()
        defer { harness.remove() }
        let image = try resource(40)
        let outside = harness.directory.appending(path: "outside", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try image.data.write(to: outside.appending(path: image.identifier + ".jpg"))
        try FileManager.default.removeItem(at: harness.covers)
        try FileManager.default.createSymbolicLink(at: harness.covers, withDestinationURL: outside)

        #expect(ReadingCoverReader(sharedDirectory: harness.shared).read(image.identifier) == nil)
        #expect(throws: (any Error).self) {
            try harness.storage().admissibleResources([image])
        }
        #expect(try Data(contentsOf: outside.appending(path: image.identifier + ".jpg")) == image.data)
    }

    @Test(arguments: ["../outside", "/absolute", "aa/../../outside", String(repeating: "A", count: 64)])
    func `invalid identifiers return no cover from an empty directory`(_ identifier: String) throws {
        let harness = try Harness()
        defer { harness.remove() }

        #expect(ReadingCoverReader(sharedDirectory: harness.shared).read(identifier) == nil)
    }
}

private extension ReadingCoverStorageTests {
    enum StorageFailure: Error { case diskFull, locked }
    enum InvalidFile: CaseIterable { case wrongDigest, truncated, oversized, symbolicLink, namedPipe }

    static let previousManifest = Data(#"{"formatVersion":1,"generatedAt":"2026-09-06T00:00:00.000Z","items":[],"publicationGeneration":"00000000-0000-0000-0000-000000000001","revision":1,"sessionGeneration":"00000000-0000-0000-0000-000000000002","state":"empty","totalEligibleCount":0}"#.utf8)
    static let expectedManifest = Data(#"{"formatVersion":1,"generatedAt":"2026-09-06T00:00:00.000Z","items":[],"publicationGeneration":"00000000-0000-0000-0000-000000000001","revision":2,"sessionGeneration":"00000000-0000-0000-0000-000000000002","state":"empty","totalEligibleCount":0}"#.utf8)
    static let receipt = Data(#"{"formatVersion":1}"#.utf8)

    func manifest(referencing identifier: String) throws -> Data {
        let item = try ReadingSnapshot.Item(
            mangaID: 27,
            title: "Retained reference",
            readingVolume: 1,
            totalVolumes: 2,
            coverResourceID: identifier
        )
        let snapshot = try ReadingSnapshot(
            publicationGeneration: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
            revision: 3,
            sessionGeneration: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2)),
            state: .content,
            generatedAt: Date(timeIntervalSince1970: 0),
            totalEligibleCount: 1,
            items: [item]
        )
        return try ReadingSnapshotCodec.encode(snapshot)
    }

    func resource(_ red: Int) throws -> ReadingCoverResource {
        let context = try #require(CGContext(
            data: nil,
            width: 16,
            height: 16,
            bitsPerComponent: 8,
            bytesPerRow: 64,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(
            red: CGFloat(red) / 255,
            green: 0.25,
            blue: 0.75,
            alpha: 1
        )
        context.fill(CGRect(
            x: 0,
            y: 0,
            width: 16,
            height: 16
        ))
        let image = try #require(context.makeImage())
        let bytes = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(
            bytes,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ))
        CGImageDestinationAddImage(destination, image, nil)
        try #require(CGImageDestinationFinalize(destination))
        return try #require(ReadingCoverResource(jpegData: bytes as Data))
    }

    func failingReceiptEffects() -> ReadingCoverStorage.Effects {
        let live = ReadingCoverStorage.Effects.live
        return ReadingCoverStorage.Effects(
            read: live.read,
            writeExclusive: { url, data in
                if url.deletingLastPathComponent().lastPathComponent == "receipts" {
                    throw StorageFailure.diskFull
                }
                try live.writeExclusive(url, data)
            },
            promoteExclusive: live.promoteExclusive,
            remove: live.remove,
            inventory: live.inventory
        )
    }

    struct Harness {
        let directory: URL
        let shared: URL
        let publisher: URL
        let covers: URL
        let admission: URL
        let receipts: URL
        let staging: URL
        let journal: URL

        func storage(effects: ReadingCoverStorage.Effects = .live) throws -> ReadingCoverStorage {
            try ReadingCoverStorage(sharedDirectory: shared, publisherDirectory: publisher, effects: effects)
        }

        func cover(_ image: ReadingCoverResource) -> URL {
            covers.appending(path: image.identifier + ".jpg")
        }

        func receipt(_ image: ReadingCoverResource) -> URL {
            receipts.appending(path: image.identifier + ".json")
        }

        func files() throws -> [String: Data] {
            var result: [String: Data] = [:]
            var pending = [directory]
            while let root = pending.popLast() {
                for url in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) {
                    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    if attributes[.type] as? FileAttributeType == .typeDirectory {
                        pending.append(url)
                    } else if attributes[.type] as? FileAttributeType == .typeRegular {
                        result[url.path] = try Data(contentsOf: url)
                    }
                }
            }
            return result
        }

        func fillQuota(leaving available: Int) throws {
            let used = try files().values.reduce(0) { $0 + $1.count }
            let padding = 8_388_608 - used - available - ReadingCoverStorageTests.receipt.count
            let identifier = String(repeating: "f", count: 64)
            try Data(repeating: 0, count: padding).write(to: covers.appending(path: identifier + ".jpg"))
            try ReadingCoverStorageTests.receipt.write(to: receipts.appending(path: identifier + ".json"))
        }

        func remove() {
            try? FileManager.default.removeItem(at: directory)
        }
    }
}

private extension ReadingCoverStorageTests.Harness {
    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(
            path: "cover-storage-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        shared = directory.appending(path: "shared", directoryHint: .isDirectory)
        publisher = directory.appending(path: "publisher", directoryHint: .isDirectory)
        covers = shared.appending(path: "covers", directoryHint: .isDirectory)
        admission = publisher.appending(path: "cover-admission", directoryHint: .isDirectory)
        receipts = admission.appending(path: "receipts", directoryHint: .isDirectory)
        staging = admission.appending(path: "staging", directoryHint: .isDirectory)
        journal = admission.appending(path: "journal.json")
        for url in [covers, receipts, staging] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
