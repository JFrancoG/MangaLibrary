#if DEBUG && targetEnvironment(simulator)
import Foundation
import SwiftUI

// Explicit Simulator-only UI/cache characterization. This does not exercise native connectivity.
// Launch with -dx5-fixture content|saved|longtitles|empty|redacted|unavailable|cache.
// Add -dx5-locale es|en and -dx5-dynamic-type large|xxxLarge|accessibility5 when needed.
// Saved delivers content, then reports temporary unavailability without removing the snapshot.
// Launch content (or another snapshot), terminate, then launch cache to restore the same synthetic file.
// Every other scenario discards only the fixture cache once per process, before delivering its snapshot.
actor WatchReadingRuntimeFixture {
    enum Scenario: String {
        case content, saved, longtitles, empty, redacted, unavailable, cache

        var snapshot: ReadingSnapshot? {
            switch self {
            case .content, .saved: WatchReadingPreview.content
            case .longtitles: WatchReadingPreview.longTitles
            case .empty: WatchReadingPreview.empty
            case .redacted: WatchReadingPreview.redacted
            case .unavailable, .cache: nil
            }
        }
    }

    struct Options {
        let scenario: Scenario
        let locale: Locale?
        let dynamicTypeSize: DynamicTypeSize?
    }

    private let scenario: Scenario
    private let storage: WatchReadingSnapshotStorage
    private let receiver: WatchReadingSnapshotReceiver
    private var hasPrepared = false

    init(scenario: Scenario) {
        let directory = URL.applicationSupportDirectory.appending(path: "DX5Validation", directoryHint: .isDirectory)
        let storage = WatchReadingSnapshotStorage(directory: directory)
        self.scenario = scenario
        self.storage = storage
        receiver = WatchReadingSnapshotReceiver(storage: storage)
    }

    @MainActor func model() -> WatchReadingModel {
        WatchReadingModel(
            receiver: receiver,
            connection: WatchReadingModel.Connection(
                run: { _, receive in
                    try await self.run(receive: receive)
                },
                requestContentDrain: { _ in }
            )
        )
    }

    private func run(receive: @Sendable (WatchReadingConnectivity.Event) async -> Void) async throws {
        try Task.checkCancellation()
        if !hasPrepared {
            if scenario != .cache {
                try storage.discard()
            }
            hasPrepared = true
        }
        if scenario == .unavailable {
            await receive(.unavailable)
            return
        }
        await receive(.activated)
        try Task.checkCancellation()
        if let snapshot = scenario.snapshot {
            let data = try ReadingSnapshotCodec.encode(snapshot)
            await receive(.received(data))
        }
        try Task.checkCancellation()
        await receive(.contentDrained)
        if scenario == .saved {
            try Task.checkCancellation()
            await receive(.unavailable)
        }
    }
}

extension WatchReadingRuntimeFixture {
    static func options(arguments: [String]) -> Options? {
        guard let rawScenario = value(for: "-dx5-fixture", arguments: arguments) else { return nil }
        guard let scenario = Scenario(rawValue: rawScenario) else {
            preconditionFailure("Unknown DX5 Simulator fixture scenario.")
        }
        let locale: Locale?
        if let identifier = value(for: "-dx5-locale", arguments: arguments) {
            precondition(identifier == "es" || identifier == "en", "DX5 fixture locale must be es or en.")
            locale = Locale(identifier: identifier)
        } else {
            locale = nil
        }
        let dynamicTypeSize: DynamicTypeSize?
        switch value(for: "-dx5-dynamic-type", arguments: arguments) {
        case nil: dynamicTypeSize = nil
        case "large": dynamicTypeSize = .large
        case "xxxLarge": dynamicTypeSize = .xxxLarge
        case "accessibility5": dynamicTypeSize = .accessibility5
        default: preconditionFailure("Unknown DX5 fixture Dynamic Type size.")
        }
        return Options(scenario: scenario, locale: locale, dynamicTypeSize: dynamicTypeSize)
    }

    private static func value(for flag: String, arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag) else { return nil }
        precondition(arguments.indices.contains(index + 1), "Missing DX5 Simulator fixture argument.")
        return arguments[index + 1]
    }
}
#endif
