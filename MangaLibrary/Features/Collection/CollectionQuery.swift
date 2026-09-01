//
//  CollectionQuery.swift
//  MangaLibrary
//

import Foundation
import SwiftData

extension CollectionEntry {
    /// Restricts an active collection fetch at the store boundary.
    ///
    /// SwiftUI and integration tests use the same predicate so neither loads
    /// another user's entries nor filters tombstones after fetching.
    static func activePredicate(userID: UUID) -> Predicate<CollectionEntry> {
        #Predicate<CollectionEntry> { entry in
            entry.userID == userID && entry.isTombstone == false
        }
    }

    /// Restricts a contextual detail fetch to one active collection identity.
    static func activePredicate(userID: UUID, mangaID: Manga.ID) -> Predicate<CollectionEntry> {
        #Predicate<CollectionEntry> { entry in
            entry.userID == userID
                && entry.mangaID == mangaID
                && entry.isTombstone == false
        }
    }
}
