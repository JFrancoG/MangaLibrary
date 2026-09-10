import Foundation
import SwiftUI

@main
struct MangaLibraryWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: WatchReadingModel
    #if DEBUG && targetEnvironment(simulator)
    private let fixtureOptions: WatchReadingRuntimeFixture.Options?
    #endif

    var body: some Scene {
        WindowGroup {
            WatchReadingView(snapshot: model.snapshot, isTemporarilyUnavailable: model.isTemporarilyUnavailable)
                #if DEBUG && targetEnvironment(simulator)
                .transformEnvironment(\.locale) { locale in
                    if let fixedLocale = fixtureOptions?.locale {
                        locale = fixedLocale
                    }
                }
                .transformEnvironment(\.dynamicTypeSize) { dynamicTypeSize in
                    if let fixedSize = fixtureOptions?.dynamicTypeSize {
                        dynamicTypeSize = fixedSize
                    }
                }
                #endif
                .task {
                    await model.run()
                }
                .task(id: scenePhase) {
                    if scenePhase == .active {
                        await model.reconcileLatestContext()
                    }
                }
        }
        .backgroundTask(.watchConnectivity) {
            await model.handleBackground()
        }
    }
}

extension MangaLibraryWatchApp {
    init() {
        #if DEBUG && targetEnvironment(simulator)
        let options = WatchReadingRuntimeFixture.options(arguments: ProcessInfo.processInfo.arguments)
        fixtureOptions = options
        if let options {
            let fixture = WatchReadingRuntimeFixture(scenario: options.scenario)
            _model = State(initialValue: fixture.model())
            return
        }
        #endif
        let directory = URL.applicationSupportDirectory.appending(path: "ReadingSnapshot", directoryHint: .isDirectory)
        let receiver = WatchReadingSnapshotReceiver(storage: WatchReadingSnapshotStorage(directory: directory))
        _model = State(initialValue: WatchReadingModel(receiver: receiver, connectivity: WatchReadingConnectivity()))
    }
}
