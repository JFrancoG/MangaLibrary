import Foundation
import ImageIO
import WidgetKit

extension ReadingWidgetEntry {
    /// Reads only the requested family's public payload; unavailable storage never reuses an older entry.
    static func loadLive(family: WidgetFamily) -> ReadingWidgetEntry {
        let date = Date()
        guard let directory = ReadingWidgetBridge.sharedDirectory() else {
            return ReadingWidgetEntry(date: date, state: .unavailable, covers: [:])
        }
        if family == .systemMedium {
            return loadCollection(directory: directory, date: date)
        }
        let reader = ReadingSnapshotReader(sharedDirectory: directory)
        switch try? reader.readResult() {
        case let .snapshot(snapshot):
            let rotation = ReadingWidgetRotation(snapshot: snapshot)
            let maximumVisibleCount = family == .systemLarge ? 6 : 1
            let identifiers = rotation.coverResourceIDs(at: date, maximumVisibleCount: maximumVisibleCount)
            let hasFewReadings = snapshot.totalEligibleCount == Int64(snapshot.items.count)
                && (1...4).contains(snapshot.items.count)
            let pixelSize = family == .systemLarge && hasFewReadings ? 384 : 160
            let covers = loadCovers(identifiers, directory: directory, pixelSize: pixelSize)
            return ReadingWidgetEntry(date: date, state: .snapshot(snapshot), covers: covers)
        case .redacted:
            return ReadingWidgetEntry(date: date, state: .redacted, covers: [:])
        case .unavailable, nil:
            return ReadingWidgetEntry(date: date, state: .unavailable, covers: [:])
        }
    }
}

private extension ReadingWidgetEntry {
    static func loadCollection(directory: URL, date: Date) -> ReadingWidgetEntry {
        let reader = CollectionWidgetReader(sharedDirectory: directory)
        switch try? reader.readResult() {
        case let .snapshot(manifest, collection):
            let rotation = CollectionWidgetRotation(snapshot: collection, generatedAt: manifest.generatedAt)
            let identifiers = rotation.coverResourceIDs(at: date)
            let covers = loadCovers(identifiers, directory: directory, pixelSize: 256)
            return ReadingWidgetEntry(
                date: date,
                state: .collection(collection, generatedAt: manifest.generatedAt),
                covers: covers
            )
        case .redacted:
            return ReadingWidgetEntry(date: date, state: .redacted, covers: [:])
        case .unavailable, nil:
            return ReadingWidgetEntry(date: date, state: .unavailable, covers: [:])
        }
    }

    static func loadCovers(_ identifiers: [String], directory: URL, pixelSize: Int) -> [String: CGImage] {
        let reader = ReadingCoverReader(sharedDirectory: directory)
        var covers: [String: CGImage] = [:]
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: pixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary
        for identifier in identifiers {
            guard
                let resource = reader.read(identifier),
                let source = CGImageSourceCreateWithData(resource.data as CFData, sourceOptions),
                let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions)
            else { continue }
            covers[identifier] = image
        }
        return covers
    }
}
