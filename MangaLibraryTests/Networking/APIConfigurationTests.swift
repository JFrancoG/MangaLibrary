//
//  APIConfigurationTests.swift
//  MangaLibraryTests
//

import Foundation
import Testing
@testable import MangaLibrary

@Suite("API configuration", .tags(.fast))
struct APIConfigurationTests {
    @Test(
        "Rejects unsafe API base URLs",
        arguments: [
            "file:///tmp/manga-library",
            "ftp://example.test",
            "https://reader:secret@example.test"
        ]
    )
    func rejectsUnsafeBaseURL(_ value: String) throws {
        let baseURL = try #require(URL(string: value))

        #expect(throws: APIConfigurationError.invalidBaseURL) {
            try APIConfiguration(baseURL: baseURL)
        }
    }
}
