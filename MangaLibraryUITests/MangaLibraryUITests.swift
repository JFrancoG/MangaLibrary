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
    func testMockCatalogOpensMangaDetail() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing")
        app.launch()

        let firstManga = app.descendants(matching: .any)["catalog.row.1"]
        XCTAssertTrue(firstManga.waitForExistence(timeout: 5))
        firstManga.tap()
        let detail = app.descendants(matching: .any)["manga.detail.1"]
        XCTAssertTrue(detail.waitForExistence(timeout: 2))
    }

    @MainActor
    func testFiltersReopenAfterDismissal() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing")
        app.launch()

        let filtersButton = app.buttons["catalog.filters"]
        XCTAssertTrue(filtersButton.waitForExistence(timeout: 5))
        filtersButton.tap()

        let compactCancelButton = app.buttons["catalog.filters.cancel.compact"]
        let regularCancelButton = app.buttons["catalog.filters.cancel.regular"]
        let cancelButton: XCUIElement
        if compactCancelButton.waitForExistence(timeout: 2) {
            cancelButton = compactCancelButton
            let sheetTop = app.coordinate(
                withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)
            )
            let sheetBottom = app.coordinate(
                withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)
            )
            sheetTop.press(forDuration: 0.1, thenDragTo: sheetBottom)
        } else {
            cancelButton = regularCancelButton
            XCTAssertTrue(cancelButton.waitForExistence(timeout: 2))
            cancelButton.tap()
        }
        XCTAssertTrue(cancelButton.waitForNonExistence(timeout: 2))

        filtersButton.tap()
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 2))
    }
}
