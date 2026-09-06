//
//  CatalogFiltersView.swift
//  MangaLibrary
//

import SwiftUI

struct CatalogFiltersView: View {
    private enum ResultSet: Hashable {
        case catalog
        case best
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let model: CatalogModel
    @Binding private var searchText: String

    @State private var resultSet: ResultSet
    @State private var matchMode: CatalogSearch.MatchMode
    @State private var title: String
    @State private var authorFirstName: String
    @State private var authorLastName: String
    @State private var selectedGenres: Set<String>
    @State private var selectedThemes: Set<String>
    @State private var selectedDemographics: Set<String>
    @State private var retryRequest: Bool?

    var body: some View {
        NavigationStack {
            Form {
                Section("Results") {
                    Picker("Result set", selection: $resultSet) {
                        Text("All manga")
                            .tag(ResultSet.catalog)
                        Text("Best manga")
                            .tag(ResultSet.best)
                    }
                    .pickerStyle(.navigationLink)
                    .accessibilityIdentifier("catalog.filters.result-set")

                    if resultSet == .best {
                        Text("Best manga is a separate server result set and cannot be combined with other filters.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }

                if resultSet == .catalog {
                    searchSections
                    filterOptionsSections
                }

                Section {
                    Button("Apply filters") {
                        applyFilters()
                    }
                    .accessibilityIdentifier("catalog.filters.apply")

                    Button("Reset filters") {
                        resetFilters()
                    }
                    .accessibilityIdentifier("catalog.filters.reset")
                }
            }
            .scrollContentBackground(.hidden)
            .background(.canvas)
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier(
                        horizontalSizeClass == .compact
                            ? "catalog.filters.cancel.compact"
                            : "catalog.filters.cancel.regular"
                    )
                }
            }
            .task(id: resultSet) {
                guard resultSet == .catalog else { return }

                await model.loadFilterOptionsIfNeeded()
            }
            .task(id: retryRequest) {
                guard retryRequest != nil, resultSet == .catalog else { return }

                await model.retryFilterOptions()
            }
        }
        .inspectorColumnWidth(min: 280, ideal: 360, max: 480)
    }

    private var searchSections: some View {
        Group {
            Section("Text matching") {
                LabeledContent("Title") {
                    TextField(text: $title) {
                        Text("Title")
                    }
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.sentences)
                }

                Picker("Match", selection: $matchMode) {
                    Text("Contains")
                        .tag(CatalogSearch.MatchMode.contains)
                    Text("Begins with")
                        .tag(CatalogSearch.MatchMode.beginsWith)
                }
            }

            Section("Author") {
                LabeledContent("First name") {
                    TextField(text: $authorFirstName) {
                        Text("First name")
                    }
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.words)
                }

                LabeledContent("Last name") {
                    TextField(text: $authorLastName) {
                        Text("Last name")
                    }
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.words)
                }
            }
        }
    }

    @ViewBuilder
    private var filterOptionsSections: some View {
        switch model.filterOptionsState {
        case .idle, .loading:
            Section {
                ProgressView("Loading filters")
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("catalog.filters.loading")
            }
        case let .content(options):
            if options == .empty {
                Section {
                    ContentUnavailableView(
                        "No filter options are available",
                        systemImage: "line.3.horizontal.decrease.circle"
                    )
                }
            } else {
                taxonomySection("Demographics", options: options.demographics, selection: $selectedDemographics)
                taxonomySection("Genres", options: options.genres, selection: $selectedGenres)
                taxonomySection("Themes", options: options.themes, selection: $selectedThemes)
            }
        case let .failure(reason):
            Section {
                ContentUnavailableView {
                    Label("Filters unavailable", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(reason.errorDescriptionResource)
                } actions: {
                    Button("Retry") {
                        retryRequest = !(retryRequest ?? false)
                    }
                }
                .accessibilityIdentifier("catalog.filters.error")
            }
        }
    }

    private func taxonomySection(
        _ title: LocalizedStringKey,
        options: [String],
        selection: Binding<Set<String>>
    ) -> some View {
        Section {
            DisclosureGroup {
                ForEach(options, id: \.self) { option in
                    Toggle(option, isOn: selectionBinding(for: option, selection: selection))
                }
            } label: {
                LabeledContent {
                    Text("Selected: \(selection.wrappedValue.count)")
                } label: {
                    Text(title)
                }
            }
        }
    }

    private func selectionBinding(for option: String, selection: Binding<Set<String>>) -> Binding<Bool> {
        Binding {
            selection.wrappedValue.contains(option)
        } set: { isSelected in
            var values = selection.wrappedValue
            if isSelected {
                values.insert(option)
            } else {
                values.remove(option)
            }
            selection.wrappedValue = values
        }
    }

    private func applyFilters() {
        switch resultSet {
        case .catalog:
            let search = CatalogSearch(
                matchMode: matchMode,
                title: title,
                authorFirstName: authorFirstName,
                authorLastName: authorLastName,
                genres: Array(selectedGenres),
                themes: Array(selectedThemes),
                demographics: Array(selectedDemographics)
            )
            model.apply(query: .search(search))
            searchText = search.title ?? ""
        case .best:
            model.apply(query: .best)
            searchText = ""
        }

        dismiss()
    }

    private func resetFilters() {
        model.apply(query: .catalog)
        searchText = ""
        dismiss()
    }
}

extension CatalogFiltersView {
    init(model: CatalogModel, searchText: Binding<String>) {
        let search = model.query.advancedSearch ?? CatalogSearch()

        self.model = model
        _searchText = searchText
        resultSet = model.query == .best ? .best : .catalog
        matchMode = search.matchMode
        title = searchText.wrappedValue
        authorFirstName = search.authorFirstName ?? ""
        authorLastName = search.authorLastName ?? ""
        selectedGenres = Set(search.genres)
        selectedThemes = Set(search.themes)
        selectedDemographics = Set(search.demographics)
    }
}

#Preview("Catalog filters") {
    CatalogFiltersView(
        model: CatalogPreviewSupport.model(
            state: .content(.init(items: CatalogPreviewSupport.mangas, pagination: .end)),
            query: .advanced(
                CatalogSearch(
                    title: "Monster",
                    authorFirstName: "Naoki",
                    authorLastName: "Urasawa",
                    genres: ["Drama"],
                    themes: ["Psychological"],
                    demographics: ["Seinen"]
                )
            ),
            filterOptionsState: .content(CatalogPreviewSupport.filterOptions)
        ),
        searchText: .constant("Monster")
    )
}

#Preview("Catalog filters loading") {
    CatalogFiltersView(
        model: CatalogPreviewSupport.model(
            state: .content(.init(items: CatalogPreviewSupport.mangas, pagination: .end)),
            filterOptionsState: .loading
        ),
        searchText: .constant("")
    )
}

#Preview("Catalog filters error") {
    CatalogFiltersView(
        model: CatalogPreviewSupport.model(
            state: .content(.init(items: CatalogPreviewSupport.mangas, pagination: .end)),
            filterOptionsState: .failure(.unavailable)
        ),
        searchText: .constant("")
    )
}

#Preview("Catalog filters empty") {
    CatalogFiltersView(
        model: CatalogPreviewSupport.model(
            state: .content(.init(items: CatalogPreviewSupport.mangas, pagination: .end)),
            filterOptionsState: .content(.empty)
        ),
        searchText: .constant("")
    )
}

#Preview("Catalog filters best manga") {
    CatalogFiltersView(
        model: CatalogPreviewSupport.model(
            state: .content(.init(items: CatalogPreviewSupport.mangas, pagination: .end)),
            query: .best
        ),
        searchText: .constant("")
    )
}
