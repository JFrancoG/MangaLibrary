//
//  MangaLibrarySchema.swift
//  MangaLibrary
//

import Foundation
import SwiftData

enum MangaLibrarySchema {
    enum V1: VersionedSchema {
        static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

        static var models: [any PersistentModel.Type] { [CollectionEntry.self, CollectionOutboxOperation.self] }
    }

    enum V2: VersionedSchema {
        static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

        static var models: [any PersistentModel.Type] { [CollectionEntry.self, CollectionOutboxOperation.self] }
    }

    enum MigrationPlan: SchemaMigrationPlan {
        static var schemas: [any VersionedSchema.Type] { [V1.self, V2.self] }

        static var stages: [MigrationStage] { [.lightweight(fromVersion: V1.self, toVersion: V2.self)] }
    }

    /// Creates a container with the app's complete versioned product-data schema.
    ///
    /// Production uses the persistent default location. Tests and deterministic
    /// automation request memory explicitly; neither mode discovers an App Group
    /// or CloudKit container from entitlements.
    static func makeContainer(isStoredInMemoryOnly: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: V2.self)
        let configuration = ModelConfiguration(
            "MangaLibrary",
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, migrationPlan: MigrationPlan.self, configurations: configuration)
    }

    /// Creates the current product container at a caller-owned disk location.
    ///
    /// Integration tests use this overload to close and reopen a real store or
    /// seed V1 before exercising the production migration plan.
    static func makeContainer(storeURL: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: V2.self)
        let configuration = ModelConfiguration(
            "MangaLibrary",
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, migrationPlan: MigrationPlan.self, configurations: configuration)
    }
}
