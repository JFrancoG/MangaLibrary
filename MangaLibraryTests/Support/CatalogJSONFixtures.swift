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
        cover: String = "https://images.example.test/fullmetal-alchemist.jpg"
    ) -> String {
        let title = includesTitle
            ? #", "title": "Fullmetal Alchemist""#
            : ""

        return #"""
        {
          "authors": [],
          "demographics": [],
          "genres": [],
          "id": \#(id),
          "mainPicture": "\#(cover)",
          "score": 9.12,
          "sypnosis": "Two brothers search for the Philosopher's Stone.",
          "status": "finished",
          "themes": [],
          "titleEnglish": "Fullmetal Alchemist",
          "titleJapanese": "鋼の錬金術師",
          "unknownRemoteField": { "canEvolve": true }\#(title)
        }
        """#
    }
}
