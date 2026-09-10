import Foundation
import Testing
@testable import MangaLibrary

@Suite("Watch reading context boundary", .tags(.fast))
struct WatchReadingContextTests {
    @Test
    func `a payload fitting the JSON limit can still exceed the complete transport budget`() {
        let data = Data(repeating: 0x20, count: 32_698)

        #expect(throws: WatchReadingConnectivityError.payloadTooLarge) {
            try WatchReadingContext.validatedData(from: ["readingSnapshot": data])
        }
    }

    @Test
    func `the complete context budget includes its exact boundary`() throws {
        let data = Data(repeating: 0x20, count: 32_697)

        let accepted = try WatchReadingContext.validatedData(from: ["readingSnapshot": data])

        #expect(accepted.count == 32_697)
    }

    @Test
    func `additional context keys are rejected before the snapshot can be accepted`() {
        let context: [String: Any] = ["readingSnapshot": Data("{}".utf8), "other": true]

        #expect(throws: WatchReadingConnectivityError.invalidContext) {
            try WatchReadingContext.validatedData(from: context)
        }
    }

    @Test(arguments: ["", "{}"])
    func `text cannot substitute for the envelope Data`(_ value: String) {
        #expect(throws: WatchReadingConnectivityError.invalidContext) {
            try WatchReadingContext.validatedData(from: ["readingSnapshot": value])
        }
    }
}
