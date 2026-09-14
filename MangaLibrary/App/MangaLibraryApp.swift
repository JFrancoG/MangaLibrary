//
//  MangaLibraryApp.swift
//  MangaLibrary
//
//  Created by Jesús Franco on 15.08.2026.
//

import SwiftUI

@main
struct MangaLibraryApp: App {
    @State private var startup: AppStartupModel

    var body: some Scene {
        WindowGroup {
            AppStartupView(model: startup)
        }
    }

}

extension MangaLibraryApp {
    init() {
        let processArguments = ProcessInfo.processInfo.arguments
#if DEBUG
        if let startup = UITestingBootstrap.makeIfRequested(processArguments: processArguments) {
            self.startup = startup
            return
        }
#else
        if processArguments.contains(where: { $0.hasPrefix("-ui-testing") }) {
            preconditionFailure("UI testing data is unavailable in production builds.")
        }
#endif
        startup = AppComposition.makeStartup()
    }
}
