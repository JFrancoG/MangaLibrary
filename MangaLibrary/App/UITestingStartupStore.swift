#if DEBUG
import Foundation
import SwiftData

/// Exercises recovery without opening product storage or falling through to live composition.
actor UITestingStartupStore {
    private var failsFirstOpening: Bool

    init(failsFirstOpening: Bool) {
        self.failsFirstOpening = failsFirstOpening
    }

    func open() throws -> ModelContainer {
        if failsFirstOpening {
            failsFirstOpening = false
            throw CocoaError(.fileReadNoPermission)
        }
        do {
            return try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        } catch {
            preconditionFailure("Manga Library could not create its UI testing data store.")
        }
    }
}
#endif
