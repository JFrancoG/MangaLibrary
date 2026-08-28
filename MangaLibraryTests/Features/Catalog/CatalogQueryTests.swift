//
//  CatalogQueryTests.swift
//  MangaLibraryTests
//

import Testing
@testable import MangaLibrary

@Suite("Catalog query identity", .tags(.fast))
struct CatalogQueryTests {
    @Test("An empty search has no criteria and collapses to the full catalog")
    func emptySearchCollapsesToCatalog() {
        let search = CatalogSearch(
            matchMode: .beginsWith,
            title: "",
            authorFirstName: "",
            authorLastName: "",
            genres: [""],
            themes: ["", ""],
            demographics: []
        )

        #expect(search.title == nil)
        #expect(search.authorFirstName == nil)
        #expect(search.authorLastName == nil)
        #expect(search.genres.isEmpty)
        #expect(search.themes.isEmpty)
        #expect(search.demographics.isEmpty)
        #expect(search.hasCriteria == false)
        #expect(CatalogQuery.search(search) == .catalog)
    }

    @Test("Selections have a stable canonical identity regardless of input order")
    func selectionsHaveStableCanonicalIdentity() {
        let unordered = CatalogSearch(
            matchMode: .contains,
            title: "Monster",
            authorFirstName: "",
            authorLastName: "",
            genres: ["Drama", "", "Action", "Drama"],
            themes: ["Psychological", "Adult Cast", "Psychological"],
            demographics: ["Seinen", "", "Seinen"]
        )
        let canonical = CatalogSearch(
            matchMode: .contains,
            title: "Monster",
            authorFirstName: "",
            authorLastName: "",
            genres: ["Action", "Drama"],
            themes: ["Adult Cast", "Psychological"],
            demographics: ["Seinen"]
        )

        #expect(unordered.genres == ["Action", "Drama"])
        #expect(unordered.themes == ["Adult Cast", "Psychological"])
        #expect(unordered.demographics == ["Seinen"])
        #expect(unordered == canonical)
        #expect(CatalogQuery.search(unordered) == .advanced(canonical))
    }

    @Test("Filter vocabularies retain selections missing from a fresh server list")
    func filterOptionsRetainCurrentSelections() {
        let options = CatalogFilterOptions(
            demographics: ["Seinen"],
            genres: ["Drama"],
            themes: ["Psychological"]
        )

        let displayedOptions = options.includingSelections(
            demographics: ["Josei"],
            genres: ["Mystery"],
            themes: ["Space"]
        )

        #expect(displayedOptions.demographics == ["Josei", "Seinen"])
        #expect(displayedOptions.genres == ["Drama", "Mystery"])
        #expect(displayedOptions.themes == ["Psychological", "Space"])
    }
}
