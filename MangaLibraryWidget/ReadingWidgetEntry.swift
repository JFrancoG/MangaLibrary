import CoreGraphics
import Foundation
import WidgetKit

struct ReadingWidgetEntry: TimelineEntry {
    enum State {
        case snapshot(ReadingSnapshot)
        case collection(CollectionWidgetSnapshot, generatedAt: Date)
        case redacted
        case unavailable
    }

    let date: Date
    let state: State
    let covers: [String: CGImage]
    let statusIllustration: CGImage?
    let items: [ReadingSnapshot.Item]
    let collectionItem: CollectionWidgetSnapshot.Item?
}

extension ReadingWidgetEntry {
    init(
        date: Date,
        state: State,
        covers: [String: CGImage],
        statusIllustration: CGImage? = nil
    ) {
        self.date = date
        self.state = state
        self.covers = covers
        self.statusIllustration = statusIllustration
        if case let .snapshot(snapshot) = state {
            items = ReadingWidgetRotation(snapshot: snapshot).items(at: date)
        } else {
            items = []
        }
        if case let .collection(snapshot, generatedAt) = state {
            collectionItem = CollectionWidgetRotation(snapshot: snapshot, generatedAt: generatedAt).item(at: date)
        } else {
            collectionItem = nil
        }
    }

    func preparingStatusIllustration(for family: WidgetFamily) -> Self {
        let needsIllustration: Bool
        switch state {
        case let .snapshot(snapshot): needsIllustration = snapshot.state == .empty
        case let .collection(snapshot, _): needsIllustration = snapshot.items.isEmpty
        case .redacted, .unavailable: needsIllustration = true
        }
        return Self(
            date: date,
            state: state,
            covers: covers,
            statusIllustration: needsIllustration ? ReadingWidgetIllustration.image(for: family) : nil
        )
    }
}
