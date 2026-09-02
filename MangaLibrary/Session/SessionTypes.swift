//
//  SessionTypes.swift
//  MangaLibrary
//

import Foundation

/// A short-lived in-process representation of one remote credential.
///
/// Raw values remain inside the session infrastructure and must never cross
/// into SwiftUI state, logs, diagnostics or user-facing errors.
struct SessionCredential: Codable, Equatable {
    let value: String
    let expiresAt: Date
}

/// The safe account details returned by the authenticated identity endpoint.
struct SessionIdentity: Equatable {
    let id: UUID
    let email: String
    let isActive: Bool
    let isAdmin: Bool
    let role: String
}
