//
//  CatalogFilterOptions.swift
//  MangaLibrary
//

import Foundation

/// Taxonomy values accepted by the advanced catalog search operation.
///
/// Values keep the server spelling used on the wire. Empty and duplicate
/// entries are removed, then the result is sorted so presentation and query
/// construction receive a stable vocabulary regardless of response order.
struct CatalogFilterOptions: Equatable {
    private let demographicsValue: [String]
    private let genresValue: [String]
    private let themesValue: [String]

    var demographics: [String] { demographicsValue }
    var genres: [String] { genresValue }
    var themes: [String] { themesValue }
}

extension CatalogFilterOptions {
    static let empty = CatalogFilterOptions(
        demographics: [],
        genres: [],
        themes: []
    )

    init(
        demographics: [String],
        genres: [String],
        themes: [String]
    ) {
        demographicsValue = Self.normalized(demographics)
        genresValue = Self.normalized(genres)
        themesValue = Self.normalized(themes)
    }

    /// Keeps active selections representable if a refreshed vocabulary omits them.
    func includingSelections(
        demographics: Set<String>,
        genres: Set<String>,
        themes: Set<String>
    ) -> Self {
        Self(
            demographics: demographicsValue + Array(demographics),
            genres: genresValue + Array(genres),
            themes: themesValue + Array(themes)
        )
    }

    private static func normalized(_ values: [String]) -> [String] {
        Array(Set(values.filter { !$0.isEmpty })).sorted()
    }
}
