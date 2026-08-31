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

    @MainActor
    func testSyntheticAccountSignsIn() throws(any Error) {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing")
        app.launch()

        let accountTab = app.buttons
            .matching(identifier: "tab.account")
            .firstMatch
        XCTAssertTrue(accountTab.waitForExistence(timeout: 5))
        accountTab.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["account.signed-out"]
                .waitForExistence(timeout: 2)
        )
        let signInAction = app.descendants(matching: .any)
            .matching(identifier: "account.sign-in.action")
            .firstMatch
        XCTAssertTrue(signInAction.waitForExistence(timeout: 2))

        let registerAction = app.descendants(matching: .any)
            .matching(identifier: "account.register.action")
            .firstMatch
        XCTAssertTrue(registerAction.waitForExistence(timeout: 2))
        XCTAssertTrue(signInAction.isHittable)
        XCTAssertTrue(registerAction.isHittable)
        XCTAssertGreaterThanOrEqual(signInAction.frame.width, 44)
        XCTAssertGreaterThanOrEqual(signInAction.frame.height, 44)
        XCTAssertLessThanOrEqual(signInAction.frame.height, 56)
        XCTAssertGreaterThanOrEqual(registerAction.frame.width, 44)
        XCTAssertGreaterThanOrEqual(registerAction.frame.height, 44)
        XCTAssertLessThanOrEqual(registerAction.frame.height, 56)

        let registrationPrompt = app.descendants(matching: .any)
            .matching(identifier: "account.register.prompt")
            .firstMatch
        XCTAssertTrue(registrationPrompt.waitForExistence(timeout: 2))
        XCTAssertLessThan(signInAction.frame.maxY, registrationPrompt.frame.minY)
        XCTAssertLessThan(registrationPrompt.frame.maxY, registerAction.frame.minY)
        XCTAssertGreaterThanOrEqual(
            registerAction.frame.minY - registrationPrompt.frame.maxY,
            12
        )

        signInAction.tap()

        let email = app.textFields["account.sign-in.email"]
        XCTAssertTrue(email.waitForExistence(timeout: 2))
        email.tap()
        email.typeText("ui-account@example.invalid")

        let password = app.secureTextFields["account.sign-in.password"]
        XCTAssertTrue(password.waitForExistence(timeout: 2))
        password.tap()
        password.typeText("synthetic-passphrase")

        app.buttons["account.sign-in.submit"].tap()
        let authenticated = app.descendants(matching: .any)[
            "account.authenticated"
        ]
        XCTAssertTrue(authenticated.waitForExistence(timeout: 2))

        let identityEmail = app.descendants(matching: .any)[
            "account.identity.email"
        ]
        XCTAssertTrue(identityEmail.waitForExistence(timeout: 2))
        XCTAssertTrue(identityEmail.label.contains("reader@example.invalid"))
        XCTAssertFalse(
            identityEmail.label.contains("ui-account@example.invalid")
        )
    }

    @MainActor
    func testSyntheticAccountRegistrationSignsIn() throws(any Error) {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing")
        app.launch()

        let accountTab = app.buttons
            .matching(identifier: "tab.account")
            .firstMatch
        XCTAssertTrue(accountTab.waitForExistence(timeout: 5))
        accountTab.tap()

        let registerAction = app.descendants(matching: .any)
            .matching(identifier: "account.register.action")
            .firstMatch
        XCTAssertTrue(registerAction.waitForExistence(timeout: 2))
        registerAction.tap()

        let email = app.textFields["account.register.email"]
        XCTAssertTrue(email.waitForExistence(timeout: 2))
        email.tap()
        email.typeText("ui-new-account@example.invalid")

        let password = app.secureTextFields["account.register.password"]
        XCTAssertTrue(password.waitForExistence(timeout: 2))
        password.tap()

        let dismissStrongPasswordSuggestion = app.buttons
            .matching(identifier: "xmark")
            .firstMatch
        if dismissStrongPasswordSuggestion.waitForExistence(timeout: 1) {
            dismissStrongPasswordSuggestion.tap()
            password.tap()
        }
        password.typeText("synthetic-passphrase")

        let submit = app.buttons["account.register.submit"]
        XCTAssertTrue(submit.isEnabled)
        submit.tap()
        let authenticated = app.descendants(matching: .any)[
            "account.authenticated"
        ]
        XCTAssertTrue(authenticated.waitForExistence(timeout: 5))

        let identityEmail = app.descendants(matching: .any)[
            "account.identity.email"
        ]
        XCTAssertTrue(identityEmail.waitForExistence(timeout: 2))
        XCTAssertTrue(identityEmail.label.contains("reader@example.invalid"))
        XCTAssertFalse(
            identityEmail.label.contains("ui-new-account@example.invalid")
        )
    }
}
