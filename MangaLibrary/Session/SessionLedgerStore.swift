//
//  SessionLedgerStore.swift
//  MangaLibrary
//

import Foundation

/// Persists non-secret session authority with atomic replacement and full protection.
struct SessionLedgerStore: Sendable {
    let fileURL: URL

    static func live() throws(SessionStorageError) -> Self {
        guard
            let bundleIdentifier = Bundle.main.bundleIdentifier,
            bundleIdentifier.isEmpty == false
        else {
            throw SessionStorageError.invalidConfiguration
        }

        let directory = URL.applicationSupportDirectory.appending(
            component: bundleIdentifier,
            directoryHint: .isDirectory
        ).appending(
            component: "Session",
            directoryHint: .isDirectory
        )
        return Self(
            fileURL: directory.appending(component: "session-ledger-v1.json")
        )
    }

    func read() throws(SessionStorageError) -> SessionLedgerRecord? {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            try removeStagingFile()
            return nil
        } catch {
            throw Self.mapFileError(error)
        }

        // Reading the protected authority must succeed before cleanup mutates
        // any artifact. A locked device therefore leaves both files untouched.
        try removeStagingFile()

        do {
            let record = try JSONDecoder().decode(
                SessionLedgerRecord.self,
                from: data
            )
            return record
        } catch let error as SessionStorageError {
            throw error
        } catch {
            throw SessionStorageError.corruptLedger
        }
    }

    func write(_ record: SessionLedgerRecord) throws(SessionStorageError) {
        let stagedURL = stagingURL
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete]
            )
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: directory.path()
            )
            var directoryValues = URLResourceValues()
            directoryValues.isExcludedFromBackup = true
            var protectedDirectory = directory
            try protectedDirectory.setResourceValues(directoryValues)
            let verifiedDirectoryValues = try directory.resourceValues(
                forKeys: [.isExcludedFromBackupKey]
            )
            guard verifiedDirectoryValues.isExcludedFromBackup == true else {
                throw SessionStorageError.fileSystemFailure
            }

            try removeStagingFile()

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(record)
            try data.write(
                to: stagedURL,
                options: [.completeFileProtection]
            )

            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            var protectedURL = stagedURL
            try protectedURL.setResourceValues(resourceValues)
            let verifiedValues = try stagedURL.resourceValues(
                forKeys: [.isExcludedFromBackupKey]
            )
            guard verifiedValues.isExcludedFromBackup == true else {
                throw SessionStorageError.fileSystemFailure
            }

            do {
                _ = try FileManager.default.replaceItemAt(
                    fileURL,
                    withItemAt: stagedURL,
                    backupItemName: nil,
                    options: [.usingNewMetadataOnly]
                )
            } catch let error as CocoaError
                where error.code == .fileNoSuchFile
                    || error.code == .fileReadNoSuchFile
            {
                try FileManager.default.moveItem(
                    at: stagedURL,
                    to: fileURL
                )
            }
        } catch {
            try? FileManager.default.removeItem(at: stagedURL)
            if let storageError = error as? SessionStorageError {
                throw storageError
            }
            throw Self.mapFileError(error)
        }
    }

    func remove() throws(SessionStorageError) {
        try removeStagingFile()

        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch let error as CocoaError
            where error.code == .fileNoSuchFile
                || error.code == .fileReadNoSuchFile
        {
            return
        } catch {
            throw Self.mapFileError(error)
        }
    }

    private var stagingURL: URL {
        fileURL.deletingLastPathComponent().appending(
            component: ".session-ledger-staging-v1.json"
        )
    }

    private func removeStagingFile() throws(SessionStorageError) {
        do {
            try FileManager.default.removeItem(at: stagingURL)
        } catch let error as CocoaError
            where error.code == .fileNoSuchFile
                || error.code == .fileReadNoSuchFile
        {
            return
        } catch {
            throw Self.mapFileError(error)
        }
    }

    private static func mapFileError(_ error: any Error) -> SessionStorageError {
        guard let cocoaError = error as? CocoaError else {
            return .fileSystemFailure
        }

        switch cocoaError.code {
        case .fileReadNoPermission, .fileWriteNoPermission:
            return .temporarilyUnavailable
        default:
            return .fileSystemFailure
        }
    }
}
