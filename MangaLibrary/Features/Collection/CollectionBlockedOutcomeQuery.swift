//
//  CollectionBlockedOutcomeQuery.swift
//  MangaLibrary
//

import Foundation
import SwiftData

extension CollectionOutboxOperation {
    /// Restricts R2.4 to durable uncertain writes owned by the active user.
    static func blockedOutcomePredicate(userID: UUID) -> Predicate<CollectionOutboxOperation> {
        let blockedOutcome = CollectionOutboxState.blockedOutcome
        return #Predicate<CollectionOutboxOperation> { operation in
            operation.userID == userID && operation.state == blockedOutcome
        }
    }
}

extension CollectionEntry {
    /// Loads presentation snapshots for active entries and tombstones of one user.
    static func userPredicate(userID: UUID) -> Predicate<CollectionEntry> {
        #Predicate<CollectionEntry> { entry in
            entry.userID == userID
        }
    }
}
