import CoreGraphics
import Foundation

enum ReadingWidgetPreview {
    static let date = Date(timeIntervalSince1970: 1_800_000_000)
    static let redacted = ReadingWidgetEntry(date: date, state: .redacted, covers: [:])
    static let unavailable = ReadingWidgetEntry(date: date, state: .unavailable, covers: [:])
    static let shortTitle = entry(titles: ["Alba"])
    static let content = entry(titles: ["The Book of Small Journeys", nil, "A Quiet Library"])
    static let collection = entry(
        titles: ["Alba", "Bosque", "Cielo", "Duna", "Estrellas", "Faro", "Girasol", "Horizonte"]
    )
    static let rotatedCollection = ReadingWidgetEntry(
        date: date.addingTimeInterval(300),
        state: collection.state,
        covers: collection.covers
    )
    static let longTitles = entry(titles: [
        "The extraordinarily long title of a journey through a library without an end",
        "Los días tranquilos de una biblioteca junto al mar",
        "A Quiet Library"
    ])
    static let empty = entry(titles: [])
    static let unknownTotal = entry(titles: [nil], firstTotalVolumes: nil)
    static let oneReading = entry(titles: ["Alba"], totalEligibleCount: 1)
    static let twoReadings = entry(titles: ["Alba", "Bosque"], totalEligibleCount: 2)
    static let threeReadings = entry(titles: ["Alba", "Bosque", "Cielo"], totalEligibleCount: 3)
    static let fourReadings = entry(titles: ["Alba", "Bosque", "Cielo", "Duna"], totalEligibleCount: 4)
    static let fiveReadings = entry(titles: ["Alba", "Bosque", "Cielo", "Duna", "Estrellas"], totalEligibleCount: 5)
    static let sixReadings = entry(
        titles: ["Alba", "Bosque", "Cielo", "Duna", "Estrellas", "Faro"],
        totalEligibleCount: 6
    )
    static let fiveLongReadings = entry(
        titles: [
            "Los días tranquilos de una biblioteca junto al mar",
            "The extraordinarily long title of a journey through a library without an end",
            "La ciudad de las estrellas que nunca dejan de brillar",
            "The small book of adventures beyond the distant horizon",
            "Los recuerdos de un bosque en el que siempre es primavera"
        ],
        totalEligibleCount: 5,
        firstReadingVolume: 300,
        firstTotalVolumes: nil
    )
    static let sixLongReadings = entry(
        titles: [
            "Los días tranquilos de una biblioteca junto al mar",
            "The extraordinarily long title of a journey through a library without an end",
            "La ciudad de las estrellas que nunca dejan de brillar",
            "The small book of adventures beyond the distant horizon",
            "Los recuerdos de un bosque en el que siempre es primavera",
            "A quiet lighthouse waiting at the end of a very long journey"
        ],
        totalEligibleCount: 6,
        firstReadingVolume: 300,
        firstTotalVolumes: nil
    )
    static let partialOneReading = entry(titles: ["Alba"], totalEligibleCount: 8)
    static let partialFourReadings = entry(titles: ["Alba", "Bosque", "Cielo", "Duna"], totalEligibleCount: 8)
    static let compactKnownProgress = entry(
        titles: ["Los días tranquilos de una biblioteca junto al mar"],
        totalEligibleCount: 1,
        firstReadingVolume: 300,
        firstTotalVolumes: 300
    )
    static let compactUnknownProgress = entry(
        titles: ["The extraordinarily long title of a journey through a library without an end"],
        totalEligibleCount: 1,
        firstReadingVolume: 300,
        firstTotalVolumes: nil
    )
    static let threeLongReadings = entry(
        titles: [
            "The extraordinarily long title of a journey through a library without an end",
            "Los días tranquilos de una biblioteca junto al mar",
            "A Quiet Library"
        ],
        totalEligibleCount: 3
    )

    private static func entry(
        titles: [String?],
        totalEligibleCount: Int64? = nil,
        firstReadingVolume: Int = 1,
        firstTotalVolumes: Int? = 12
    ) -> ReadingWidgetEntry {
        do {
            let identifier = String(repeating: "a", count: 64)
            let items = try titles.enumerated().map { index, title in
                try ReadingSnapshot.Item(
                    mangaID: Int64(index + 1),
                    title: title,
                    readingVolume: index == 0 ? firstReadingVolume : (index == 2 ? 12 : index + 1),
                    totalVolumes: index == 0 ? firstTotalVolumes : (index == 1 ? nil : 12),
                    coverResourceID: index == 0 ? identifier : nil
                )
            }
            let snapshot = try ReadingSnapshot(
                publicationGeneration: UUID(uuid: (1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
                revision: 1,
                sessionGeneration: UUID(uuid: (2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2)),
                state: items.isEmpty ? .empty : .content,
                generatedAt: date,
                totalEligibleCount: totalEligibleCount ?? (items.isEmpty ? 0 : Int64(max(7, items.count))),
                items: items
            )
            let covers = cover.map { [identifier: $0] } ?? [:]
            return ReadingWidgetEntry(date: date, state: .snapshot(snapshot), covers: covers)
        } catch {
            return unavailable
        }
    }

    private static var cover: CGImage? {
        guard let context = CGContext(
            data: nil,
            width: 64,
            height: 96,
            bitsPerComponent: 8,
            bytesPerRow: 64 * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.setFillColor(CGColor(red: 0.48, green: 0.08, blue: 0.14, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 64, height: 96))
        context.setFillColor(CGColor(red: 0.99, green: 0.96, blue: 0.90, alpha: 1))
        context.fill(CGRect(x: 12, y: 26, width: 40, height: 4))
        context.fill(CGRect(x: 12, y: 38, width: 30, height: 4))
        context.fill(CGRect(x: 12, y: 62, width: 40, height: 20))
        return context.makeImage()
    }
}
