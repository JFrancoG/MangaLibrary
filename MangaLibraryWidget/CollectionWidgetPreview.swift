import Foundation

enum CollectionWidgetPreview {
    static let date = ReadingWidgetPreview.date
    static let content = entry([
        (title: "Alba", owned: 5, total: 12, complete: false),
        (title: "Bosque", owned: 12, total: 12, complete: true),
        (title: "Faro", owned: 3, total: nil, complete: false)
    ])
    static let rotated = ReadingWidgetEntry(
        date: date.addingTimeInterval(300),
        state: content.state,
        covers: content.covers
    )
    static let completed = entry([(title: "Bosque", owned: 12, total: 12, complete: true)])
    static let unknownTotal = entry([(title: nil, owned: 5, total: nil, complete: false)])
    static let zeroOwned = entry([(title: "A Quiet Library", owned: 0, total: 12, complete: false)])
    static let oneOwned = entry([(title: "Alba", owned: 1, total: nil, complete: false)])
    static let longTitle = entry([
        (title: "Los días tranquilos de una biblioteca junto al mar", owned: 5, total: 12, complete: false)
    ])
    static let largeCounts = entry([
        (title: "A library beyond the farthest horizon", owned: 300, total: 300, complete: true)
    ])
    static let maximumCollection = entry(Array(
        repeating: (title: "Bosque de tinta", owned: 299, total: 300, complete: false),
        count: 4_096
    ))
    static let twentyFourManga = entry(Array(
        repeating: (title: "Los días tranquilos de una biblioteca junto al mar", owned: 5, total: 12, complete: false),
        count: 24
    ))
    static let empty = entry([])
    static let redacted = ReadingWidgetEntry(date: date, state: .redacted, covers: [:])
    static let unavailable = ReadingWidgetEntry(date: date, state: .unavailable, covers: [:])

    private static func entry(
        _ records: [(title: String?, owned: Int, total: Int?, complete: Bool)]
    ) -> ReadingWidgetEntry {
        do {
            let identifier = String(repeating: "a", count: 64)
            let items = try records.enumerated().map { index, record in
                try CollectionWidgetSnapshot.Item(
                    mangaID: Int64(index + 101),
                    title: record.title,
                    ownedVolumeCount: record.owned,
                    totalVolumes: record.total,
                    isComplete: record.complete,
                    coverResourceID: index == 0 ? identifier : nil
                )
            }
            let snapshot = try CollectionWidgetSnapshot(items: items)
            return ReadingWidgetEntry(
                date: date,
                state: .collection(snapshot, generatedAt: date),
                covers: ReadingWidgetPreview.content.covers
            )
        } catch {
            return unavailable
        }
    }
}
