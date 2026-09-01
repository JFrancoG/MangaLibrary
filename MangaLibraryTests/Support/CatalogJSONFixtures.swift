//
//  CatalogJSONFixtures.swift
//  MangaLibraryTests
//

import Foundation

enum CatalogJSONFixtures {
    static func page(
        page: Int64 = 1,
        per: Int64 = 20,
        total: Int64 = 1,
        items: [String]? = nil
    ) -> Data {
        let items = items ?? [manga()]

        return Data(
            #"{"items":[\#(items.joined(separator: ","))],"metadata":{"page":\#(page),"per":\#(per),"total":\#(total)}}"#.utf8
        )
    }

    static func manga(
        id: Int64 = 42,
        includesTitle: Bool = true,
        includesAuthors: Bool = true,
        authorID: String = "11111111-1111-1111-1111-111111111111",
        authorRole: String = "Story & Art",
        status: String = "finished",
        cover: String = "https://images.example.test/fullmetal-alchemist.jpg"
    ) -> String {
        let title = includesTitle ? #", "title": "Fullmetal Alchemist""# : ""
        let authors = includesAuthors
            ? #""authors": [{"id":"\#(authorID)","firstName":"Hiromu","lastName":"Arakawa","role":"\#(authorRole)"}],"#
            : ""

        return #"""
        {
          \#(authors)
          "demographics": [{"id":"22222222-2222-2222-2222-222222222222","demographic":"Shounen"}],
          "genres": [{"id":"33333333-3333-3333-3333-333333333333","genre":"Adventure"}],
          "id": \#(id),
          "mainPicture": "\#(cover)",
          "score": 9.12,
          "sypnosis": "Two brothers search for the Philosopher's Stone.",
          "status": "\#(status)",
          "themes": [{"id":"44444444-4444-4444-4444-444444444444","theme":"Military"}],
          "titleEnglish": "Fullmetal Alchemist",
          "titleJapanese": "鋼の錬金術師",
          "unknownRemoteField": { "canEvolve": true }\#(title)
        }
        """#
    }
}
