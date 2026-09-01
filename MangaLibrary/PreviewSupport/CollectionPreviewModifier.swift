//
//  CollectionPreviewModifier.swift
//  MangaLibrary
//

import SwiftData
import SwiftUI

struct CollectionPreviewModifier<Scenario: CollectionPreviewScenario>: PreviewModifier {
    static func makeSharedContext() throws -> ModelContainer {
        try CollectionPreviewSupport.makeContainer(seed: Scenario.seed)
    }

    func body(content: Content, context: ModelContainer) -> some View {
        content.modelContainer(context)
    }
}

protocol CollectionPreviewScenario {
    static var seed: CollectionPreviewSeed { get }
}

enum CollectionPreviewScenarios {
    enum Shell: CollectionPreviewScenario {
        static let seed = CollectionPreviewSeed.content
    }

    enum Content: CollectionPreviewScenario {
        static let seed = CollectionPreviewSeed.content
    }

    enum Empty: CollectionPreviewScenario {
        static let seed = CollectionPreviewSeed.empty
    }

    enum ReadOnly: CollectionPreviewScenario {
        static let seed = CollectionPreviewSeed.content
    }

    enum SignedOut: CollectionPreviewScenario {
        static let seed = CollectionPreviewSeed.empty
    }

    enum Restoring: CollectionPreviewScenario {
        static let seed = CollectionPreviewSeed.empty
    }

    enum RestorationFailed: CollectionPreviewScenario {
        static let seed = CollectionPreviewSeed.empty
    }

    enum UserRoot: CollectionPreviewScenario {
        static let seed = CollectionPreviewSeed.content
    }

    enum Controls: CollectionPreviewScenario {
        static let seed = CollectionPreviewSeed.content
    }

    enum ControlsEmpty: CollectionPreviewScenario {
        static let seed = CollectionPreviewSeed.empty
    }

    enum ControlsSignedOut: CollectionPreviewScenario {
        static let seed = CollectionPreviewSeed.empty
    }

    enum ControlsReadOnly: CollectionPreviewScenario {
        static let seed = CollectionPreviewSeed.content
    }

    enum EntryDetail: CollectionPreviewScenario {
        static let seed = CollectionPreviewSeed.content
    }

    enum MigratedEntryDetail: CollectionPreviewScenario {
        static let seed = CollectionPreviewSeed.content
    }

    enum Row: CollectionPreviewScenario {
        static let seed = CollectionPreviewSeed.content
    }

    enum KnownTotalEditor: CollectionPreviewScenario {
        static let seed = CollectionPreviewSeed.content
    }

    enum UnknownTotalEditor: CollectionPreviewScenario {
        static let seed = CollectionPreviewSeed.content
    }
}
