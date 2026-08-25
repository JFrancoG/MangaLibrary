//
//  MangaLibraryUITests.swift
//  MangaLibraryUITests
//
//  Created by Jesús Franco on 15.08.2026.
//

import XCTest

final class MangaLibraryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCatalogOpensDetailAndSurvivesTabChanges() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-catalog-fixture", "content"]
        app.launch()

        let catalogTab = app.buttons.matching(identifier: "tab.catalog").firstMatch
        let collectionTab = app.buttons.matching(identifier: "tab.collection").firstMatch
        let accountTab = app.buttons.matching(identifier: "tab.account").firstMatch

        XCTAssertTrue(catalogTab.waitForExistence(timeout: 5))
        XCTAssertTrue(collectionTab.exists)
        XCTAssertTrue(accountTab.exists)

        let firstManga = app.descendants(matching: .any)["catalog.row.1"]
        XCTAssertTrue(firstManga.waitForExistence(timeout: 5))

        firstManga.tap()
        let detail = app.descendants(matching: .any)["manga.detail.1"]
        XCTAssertTrue(detail.waitForExistence(timeout: 2))

        collectionTab.tap()
        XCTAssertTrue(app.descendants(matching: .any)["collection.unavailable"].waitForExistence(timeout: 2))

        accountTab.tap()
        XCTAssertTrue(app.descendants(matching: .any)["account.unavailable"].waitForExistence(timeout: 2))

        catalogTab.tap()
        XCTAssertTrue(detail.waitForExistence(timeout: 2))
    }
}
