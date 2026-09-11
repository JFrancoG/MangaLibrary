//
//  CollectionOutboxQuery.swift
//  MangaLibrary
//

import Foundation
import SwiftData

extension CollectionOutboxOperation {
    /// Fetches every outbox state for the authenticated user, or nothing without one.
    ///
    /// Confirmed operations remain part of the synchronization identity so ordinary
    /// worker transitions do not cancel and restart the shell's synchronization task.
    static func userPredicate(userID: UUID?) -> Predicate<CollectionOutboxOperation> {
        guard let userID else {
            return #Predicate<CollectionOutboxOperation> { _ in false }
        }

        return #Predicate<CollectionOutboxOperation> { operation in
            operation.userID == userID
        }
    }
}
