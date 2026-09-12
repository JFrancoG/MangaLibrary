//
//  CatalogQuery.swift
//  MangaLibrary
//

/// The semantic identity of a catalog result sequence.
///
/// Best manga is an exclusive server operation. Advanced searches instead carry
/// every text and filter dimension that can change their paginated results.
enum CatalogQuery: Hashable {
    case catalog
    case best
    case advanced(CatalogSearch)

    var advancedSearch: CatalogSearch? {
        guard case let .advanced(search) = self else { return nil }

        return search
    }

    /// The active non-title filter dimensions represented by the query.
    ///
    /// Best manga counts as one active mode; title text remains visible in the
    /// search field and is therefore excluded from the filter badge.
    var activeFilterCount: Int {
        switch self {
        case .catalog:
            0
        case .best:
            1
        case let .advanced(search):
            search.activeFilterCount
        }
    }

    /// Collapses a normalized search without criteria to the full catalog.
    static func search(_ search: CatalogSearch) -> Self {
        search.hasCriteria ? .advanced(search) : .catalog
    }
}

/// A normalized, hash-stable advanced-search identity.
///
/// Empty text and taxonomy values are absent. Taxonomy values are unique and
/// lexicographically ordered, so equivalent selections always compare equally.
struct CatalogSearch: Hashable {
    enum MatchMode: Hashable {
        case contains
        case beginsWith

        var searchContains: Bool { self == .contains }
    }

    let matchMode: MatchMode

    private let normalizedTitle: String?
    private let normalizedAuthorFirstName: String?
    private let normalizedAuthorLastName: String?
    private let normalizedGenres: [String]
    private let normalizedThemes: [String]
    private let normalizedDemographics: [String]

    var title: String? { normalizedTitle }

    var authorFirstName: String? { normalizedAuthorFirstName }

    var authorLastName: String? { normalizedAuthorLastName }

    var genres: [String] { normalizedGenres }

    var themes: [String] { normalizedThemes }

    var demographics: [String] { normalizedDemographics }

    var hasCriteria: Bool {
        title != nil
            || authorFirstName != nil
            || authorLastName != nil
            || genres.isEmpty == false
            || themes.isEmpty == false
            || demographics.isEmpty == false
    }

    var activeFilterCount: Int {
        let hasAuthorship = authorFirstName != nil || authorLastName != nil

        return [
            hasAuthorship,
            genres.isEmpty == false,
            themes.isEmpty == false,
            demographics.isEmpty == false
        ]
        .count { $0 }
    }
}

extension CatalogSearch {
    /// Creates an identity after removing absent values and canonicalizing selections.
    init(
        matchMode: MatchMode = .contains,
        title: String? = nil,
        authorFirstName: String? = nil,
        authorLastName: String? = nil,
        genres: [String] = [],
        themes: [String] = [],
        demographics: [String] = []
    ) {
        self.matchMode = matchMode
        normalizedTitle = Self.normalizedText(title)
        normalizedAuthorFirstName = Self.normalizedText(authorFirstName)
        normalizedAuthorLastName = Self.normalizedText(authorLastName)
        normalizedGenres = Self.normalizedValues(genres)
        normalizedThemes = Self.normalizedValues(themes)
        normalizedDemographics = Self.normalizedValues(demographics)
    }

    /// Returns the same normalized identity with a replacement title.
    func replacingTitle(_ title: String?) -> Self {
        Self(
            matchMode: matchMode,
            title: title,
            authorFirstName: authorFirstName,
            authorLastName: authorLastName,
            genres: genres,
            themes: themes,
            demographics: demographics
        )
    }

    private static func normalizedText(_ value: String?) -> String? {
        guard let value, value.isEmpty == false else { return nil }

        return value
    }

    private static func normalizedValues(_ values: [String]) -> [String] {
        Set(values.filter { $0.isEmpty == false }).sorted()
    }
}
