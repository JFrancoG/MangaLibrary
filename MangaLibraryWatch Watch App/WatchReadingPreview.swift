import Foundation

enum WatchReadingPreview {
    static let content = snapshot(titles: ["A Quiet Library", nil, "The Book of Small Journeys"])
    static let longTitles = snapshot(titles: [
        "Las historias de una biblioteca junto al mar y de todos los viajes que todavía quedan por descubrir",
        "The extraordinarily long title of a journey through a library without an end",
        "A Quiet Library"
    ])
    static let empty = snapshot(titles: [])
    static let redacted = snapshot(titles: [], state: .redacted)

    private static func snapshot(titles: [String?], state: ReadingSnapshot.State? = nil) -> ReadingSnapshot {
        do {
            let items = try titles.enumerated().map { index, title in
                try ReadingSnapshot.Item(
                    mangaID: Int64(index + 1),
                    title: title,
                    readingVolume: index == 2 ? 12 : index + 1,
                    totalVolumes: index == 1 ? nil : 12,
                    coverResourceID: index == 0 ? String(repeating: "a", count: 64) : nil
                )
            }
            let snapshotState = state ?? (items.isEmpty ? .empty : .content)
            return try ReadingSnapshot(
                publicationGeneration: UUID(uuid: (1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
                revision: 1,
                sessionGeneration: UUID(uuid: (2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2)),
                state: snapshotState,
                generatedAt: Date(timeIntervalSince1970: 1_788_998_400),
                totalEligibleCount: snapshotState == .redacted ? nil : (items.isEmpty ? 0 : 8),
                items: items
            )
        } catch {
            preconditionFailure("Invalid deterministic watch preview fixture: \(error)")
        }
    }
}
