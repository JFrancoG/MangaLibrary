//
//  AppCompositionTests.swift
//  MangaLibraryTests
//

import Testing
@testable import MangaLibrary

@Suite("App composition")
struct AppCompositionTests {
    @Test("Reads the scenario immediately after the catalog fixture flag")
    func readsCatalogFixtureScenario() {
        let scenario = CatalogFixtureScenario(
            arguments: ["MangaLibrary", "-catalog-fixture", "content"]
        )

        #expect(scenario == .content)
    }

    @Test("Rejects missing and incomplete catalog fixture arguments")
    func rejectsMissingCatalogFixtureScenario() {
        #expect(CatalogFixtureScenario(arguments: ["MangaLibrary"]) == nil)
        #expect(
            CatalogFixtureScenario(
                arguments: ["MangaLibrary", "-catalog-fixture"]
            ) == nil
        )
    }

    @Test("An invalid requested fixture cannot fall through to the live client")
    func rejectsInvalidCatalogFixtureScenario() {
        #expect(throws: AppComposition.CreationError.invalidCatalogFixture) {
            try AppComposition.current(
                arguments: ["MangaLibrary", "-catalog-fixture", "unknown"]
            )
        }
    }
}
