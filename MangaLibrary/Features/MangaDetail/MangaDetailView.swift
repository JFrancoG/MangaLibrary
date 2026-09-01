//
//  MangaDetailView.swift
//  MangaLibrary
//

import Foundation
import SwiftUI

struct MangaDetailView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.locale) private var locale

    @State private var coverScale: CGFloat = 0.1
    @State private var scrollPosition = ScrollPosition(idType: Manga.ID.self)

    let manga: Manga

    var body: some View {
        if horizontalSizeClass == .compact {
            if accessibilityReduceMotion {
                content
                    .navigationTransition(.crossFade)
            } else {
                content
            }
        } else {
            content
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                detailCover

                Text(manga.title)
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(.textPrimary)
                    .accessibilityHeading(.h1)

                if let titleEnglish = manga.titleEnglish, titleEnglish != manga.title {
                    Text(titleEnglish)
                        .font(.title3)
                        .foregroundStyle(.textPrimary)
                }

                if let titleJapanese = manga.titleJapanese {
                    Text(titleJapanese)
                        .font(.title3)
                        .foregroundStyle(.textPrimary)
                }

                LabeledContent("Score") {
                    Text(manga.score, format: .number.precision(.fractionLength(1...2)))
                    .foregroundStyle(.textPrimary)
                }
                .foregroundStyle(.textSecondary)

                LabeledContent("Status") {
                    Text(manga.status.localizedTitle)
                        .foregroundStyle(.textPrimary)
                }
                .foregroundStyle(.textSecondary)

                if manga.authors.isEmpty == false {
                    detailSection("Authors") {
                        ForEach(manga.authors) { author in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(formattedName(for: author))
                                    .font(.body)
                                    .foregroundStyle(.textPrimary)
                                Text(author.role.localizedTitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.textSecondary)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }

                if hasClassifications {
                    detailSection("Classification") {
                        classification("Demographics", values: manga.demographics)
                        classification("Genres", values: manga.genres)
                        classification("Themes", values: manga.themes)
                    }
                }

                if let synopsis = manga.synopsis {
                    detailSection("Synopsis") {
                        Text(synopsis)
                            .font(.body)
                            .foregroundStyle(.textPrimary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(Color(.canvas))
        .scrollPosition($scrollPosition)
        .onChange(of: manga.id) { _, _ in
            guard horizontalSizeClass == .regular else { return }

            scrollPosition.scrollTo(edge: .top)
        }
        .navigationTitle(manga.title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("manga.detail.\(manga.id)")
    }

    private var detailCover: some View {
        MangaCoverView(url: manga.coverURL, presentation: .detail)
        .frame(maxWidth: .infinity)
        .scaleEffect(shouldAnimateCover ? coverScale : 1)
        .onAppear {
            animateCover()
        }
    }

    private var shouldAnimateCover: Bool {
        horizontalSizeClass == .compact && accessibilityReduceMotion == false
    }

    private func animateCover() {
        guard shouldAnimateCover else {
            coverScale = 1
            return
        }

        coverScale = 0.1
        withAnimation(
            .easeIn(duration: 0.3),
            completionCriteria: .removed
        ) {
            coverScale = 1.25
        } completion: {
            withAnimation(.easeOut(duration: 0.08)) {
                coverScale = 1
            }
        }
    }

    private var hasClassifications: Bool {
        manga.demographics.isEmpty == false || manga.genres.isEmpty == false || manga.themes.isEmpty == false
    }

    private func formattedName(for author: Manga.Author) -> String {
        author.nameComponents.formatted(
            .name(style: .medium)
                .locale(locale)
        )
    }

    @ViewBuilder
    private func classification(_ title: LocalizedStringKey, values: [Manga.Classification]) -> some View {
        if values.isEmpty == false {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.textSecondary)
                Text(
                    values
                        .map(\.name)
                        .formatted(
                            .list(type: .and)
                                .locale(locale)
                        )
                )
                .font(.body)
                .foregroundStyle(.textPrimary)
            }
        }
    }

    private func detailSection<Content: View>(
        _ title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.textPrimary)
                .accessibilityHeading(.h2)
            content()
        }
    }
}

private extension Manga.Status {
    var localizedTitle: LocalizedStringResource {
        switch self {
        case .discontinued: "Discontinued"
        case .onHiatus: "On hiatus"
        case .publishing: "Publishing"
        case .finished: "Finished"
        case .unspecified: "Status unavailable"
        }
    }
}

private extension Manga.Author.Role {
    var localizedTitle: LocalizedStringResource {
        switch self {
        case .art: "Art"
        case .storyAndArt: "Story and art"
        case .story: "Story"
        case .unspecified: "Role unavailable"
        }
    }
}

#Preview("Manga detail") {
    NavigationStack {
        MangaDetailView(manga: CatalogPreviewSupport.mangas[0])
    }
}
