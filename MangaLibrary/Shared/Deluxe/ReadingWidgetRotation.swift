import Foundation

/// Plans a bounded presentation timeline without changing the snapshot's canonical order.
///
/// The publication date anchors five-minute slots. Reloads resume that phase, while a new
/// visible publication can start from its preferred manga. Adjacent windows overlap so
/// reducing the number of displayed rows never skips a reading.
struct ReadingWidgetRotation {
    let snapshot: ReadingSnapshot

    func timelineDates(at date: Date) -> [Date] {
        guard snapshot.state == .content, snapshot.items.count > 1 else { return [date] }
        let slotStart = snapshot.generatedAt.addingTimeInterval(slotOffset(at: date))
        return [min(date, slotStart)] + (1...12).map { slot in
            slotStart.addingTimeInterval(TimeInterval(slot) * 300)
        }
    }

    func items(at date: Date) -> [ReadingSnapshot.Item] {
        guard snapshot.state == .content, snapshot.items.count > 1 else { return snapshot.items }
        let preferredIndex = snapshot.items.firstIndex { $0.mangaID == snapshot.preferredStartMangaID } ?? 0
        let steps = slotOffset(at: date) / 300
        let shift = Int(steps.truncatingRemainder(dividingBy: Double(snapshot.items.count)))
        let startIndex = (preferredIndex + shift) % snapshot.items.count
        return Array(snapshot.items[startIndex...]) + snapshot.items[..<startIndex]
    }

    func coverResourceIDs(at date: Date, maximumVisibleCount: Int) -> [String] {
        var identifiers: [String] = []
        var seen: Set<String> = []
        for entryDate in timelineDates(at: date) {
            for item in items(at: entryDate).prefix(max(0, min(maximumVisibleCount, 6))) {
                if let identifier = item.coverResourceID, seen.insert(identifier).inserted {
                    identifiers.append(identifier)
                }
            }
        }
        return identifiers
    }
}

private extension ReadingWidgetRotation {
    func slotOffset(at date: Date) -> TimeInterval {
        floor(max(0, date.timeIntervalSince(snapshot.generatedAt)) / 300) * 300
    }
}

/// Starts at the published local-addition focus, then follows canonical order without rotating the full array.
struct CollectionWidgetRotation {
    let snapshot: CollectionWidgetSnapshot
    let generatedAt: Date

    func timelineDates(at date: Date) -> [Date] {
        guard snapshot.items.count > 1 else { return [date] }
        let slotStart = generatedAt.addingTimeInterval(slotOffset(at: date))
        return [min(date, slotStart)] + (1...12).map { slot in
            slotStart.addingTimeInterval(TimeInterval(slot) * 300)
        }
    }

    func item(at date: Date) -> CollectionWidgetSnapshot.Item? {
        guard !snapshot.items.isEmpty else { return nil }
        let preferredIndex = snapshot.items.firstIndex { $0.mangaID == snapshot.preferredStartMangaID } ?? 0
        let steps = slotOffset(at: date) / 300
        let shift = Int(steps.truncatingRemainder(dividingBy: Double(snapshot.items.count)))
        let index = (preferredIndex + shift) % snapshot.items.count
        return snapshot.items[index]
    }

    func coverResourceIDs(at date: Date) -> [String] {
        var identifiers: [String] = []
        var seen: Set<String> = []
        for entryDate in timelineDates(at: date) {
            if let identifier = item(at: entryDate)?.coverResourceID, seen.insert(identifier).inserted {
                identifiers.append(identifier)
            }
        }
        return identifiers
    }
}

private extension CollectionWidgetRotation {
    func slotOffset(at date: Date) -> TimeInterval {
        floor(max(0, date.timeIntervalSince(generatedAt)) / 300) * 300
    }
}
