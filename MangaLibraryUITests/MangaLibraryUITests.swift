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

        let collectionDisclosure = app.buttons["collection.disclosure.1"]
        for _ in 0..<4 where collectionDisclosure.exists == false {
            detail.swipeUp()
        }
        XCTAssertTrue(collectionDisclosure.waitForExistence(timeout: 2))
        for _ in 0..<4 where collectionDisclosure.isHittable == false {
            detail.swipeUp()
        }
        XCTAssertTrue(collectionDisclosure.isHittable)

        let signedOutMessage = app.descendants(matching: .any)["collection.controls.unavailable"]
        XCTAssertTrue(signedOutMessage.waitForExistence(timeout: 2))
        collectionDisclosure.tap()
        XCTAssertTrue(signedOutMessage.waitForNonExistence(timeout: 2))
        collectionDisclosure.tap()
        XCTAssertTrue(signedOutMessage.waitForExistence(timeout: 2))
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
            let sheetTop = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08))
            let sheetBottom = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
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
    func testCatalogDetailSavesAndDeletesMangaFromCollection() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing")
        app.launch()

        let accountTab = app.buttons.matching(identifier: "tab.account").firstMatch
        XCTAssertTrue(accountTab.waitForExistence(timeout: 5))
        accountTab.tap()

        let signInAction = app.descendants(matching: .any)
            .matching(identifier: "account.sign-in.action")
            .firstMatch
        XCTAssertTrue(signInAction.waitForExistence(timeout: 2))
        signInAction.tap()

        let email = app.textFields["account.sign-in.email"]
        XCTAssertTrue(email.waitForExistence(timeout: 2))
        email.tap()
        email.typeText("ui-collection@example.invalid")

        let password = app.secureTextFields["account.sign-in.password"]
        XCTAssertTrue(password.waitForExistence(timeout: 2))
        password.tap()
        password.typeText("synthetic-passphrase")

        let signInSubmit = app.buttons["account.sign-in.submit"]
        XCTAssertTrue(signInSubmit.waitForExistence(timeout: 2))
        signInSubmit.tap()
        XCTAssertTrue(app.descendants(matching: .any)["account.authenticated"].waitForExistence(timeout: 2))

        let collectionTab = app.buttons.matching(identifier: "tab.collection").firstMatch
        XCTAssertTrue(collectionTab.waitForExistence(timeout: 2))
        collectionTab.tap()

        let importedManga = app.descendants(matching: .any)
            .matching(identifier: "collection.row.2")
            .firstMatch
        XCTAssertTrue(importedManga.waitForExistence(timeout: 5))
        XCTAssertTrue(importedManga.label.contains("A deliberately long manga title"))

        let catalogTab = app.buttons.matching(identifier: "tab.catalog").firstMatch
        XCTAssertTrue(catalogTab.waitForExistence(timeout: 2))
        catalogTab.tap()

        let firstManga = app.descendants(matching: .any)["catalog.row.1"]
        XCTAssertTrue(firstManga.waitForExistence(timeout: 5))
        firstManga.tap()
        let detail = app.descendants(matching: .any)["manga.detail.1"]
        XCTAssertTrue(detail.waitForExistence(timeout: 2))

        let addToCollection = app.buttons["collection.add.1"]
        for _ in 0..<4 where addToCollection.exists == false {
            detail.swipeUp()
        }
        XCTAssertTrue(addToCollection.waitForExistence(timeout: 2))
        if addToCollection.isHittable == false {
            app.swipeUp()
        }
        XCTAssertTrue(addToCollection.isHittable)
        addToCollection.tap()

        let firstVolume = app.switches["collection.editor.owned-volume.1"]
        XCTAssertTrue(firstVolume.waitForExistence(timeout: 2))
        XCTAssertEqual(firstVolume.value as? String, "0")
        firstVolume.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(firstVolume.value as? String, "1")

        let cancel = app.buttons["collection.editor.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 2))
        XCTAssertTrue(["Cancel", "Cancelar"].contains(cancel.label))

        let save = app.buttons["collection.editor.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 2))
        XCTAssertTrue(["Save", "Guardar"].contains(save.label))
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 2))

        collectionTab.tap()

        let savedManga = app.descendants(matching: .any)
            .matching(identifier: "collection.row.1")
            .firstMatch
        XCTAssertTrue(savedManga.waitForExistence(timeout: 2))
        XCTAssertTrue(savedManga.label.contains("Fullmetal Alchemist"))
        savedManga.tap()

        let editCollection = app.buttons["collection.entry.edit.1"]
        XCTAssertTrue(editCollection.waitForExistence(timeout: 2))
        let presentsBottomTabBar = collectionTab.frame.midY > app.windows.firstMatch.frame.midY
        if presentsBottomTabBar {
            for _ in 0..<4 where editCollection.frame.maxY >= collectionTab.frame.minY {
                app.swipeUp(velocity: .slow)
            }
            XCTAssertLessThan(editCollection.frame.maxY, collectionTab.frame.minY)
        }
        XCTAssertTrue(editCollection.isHittable)
        editCollection.tap()

        let editorSave = app.buttons["collection.editor.save"]
        XCTAssertTrue(editorSave.waitForExistence(timeout: 5))
        let deleteButton = app.buttons["collection.editor.delete"]
        for _ in 0..<4 where deleteButton.exists == false {
            app.swipeUp()
        }
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 2))
        for _ in 0..<4 where deleteButton.isHittable == false {
            app.swipeUp()
        }
        XCTAssertTrue(deleteButton.isHittable)
        XCTAssertTrue(["Remove from Collection", "Eliminar de la colección"].contains(deleteButton.label))
        deleteButton.tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        let alertText = Set(alert.staticTexts.allElementsBoundByIndex.map(\.label))
        XCTAssertTrue(
            [
                "Remove “Fullmetal Alchemist” from your collection?",
                "¿Eliminar «Fullmetal Alchemist» de tu colección?",
            ].contains(where: alertText.contains)
        )
        XCTAssertTrue(
            [
                """
                The volumes marked as owned and your reading progress will be deleted. \
                You can add the manga again, but that data won’t be restored.
                """,
                """
                Se borrarán los tomos marcados y tu progreso de lectura. \
                Podrás volver a añadir el manga, pero esos datos no se recuperarán.
                """,
            ].contains(where: alertText.contains)
        )
        let cancelDeletion = alert.buttons
            .matching(identifier: "collection.editor.delete.cancel")
            .firstMatch
        XCTAssertTrue(cancelDeletion.waitForExistence(timeout: 2))
        cancelDeletion.tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 2))
        XCTAssertTrue(deleteButton.exists)

        deleteButton.tap()
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        let confirmDeletion = alert.buttons
            .matching(identifier: "collection.editor.delete.confirm")
            .firstMatch
        XCTAssertTrue(confirmDeletion.waitForExistence(timeout: 2))
        XCTAssertTrue(["Remove", "Eliminar"].contains(confirmDeletion.label))
        confirmDeletion.tap()

        XCTAssertTrue(deleteButton.waitForNonExistence(timeout: 2))
        XCTAssertTrue(importedManga.waitForExistence(timeout: 2))
        XCTAssertTrue(savedManga.waitForNonExistence(timeout: 2))
    }

    @MainActor
    func testCollectionDetailUsesRootProjection() throws {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: [
            "-ui-testing",
            "-ui-testing-collection-detail-projection",
        ])
        app.launch()

        let detail = app.descendants(matching: .any)["manga.detail.2"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        XCTAssertTrue(
            ["Owned, 1 and 12", "En propiedad, 1 y 12"].contains {
                app.staticTexts[$0].waitForExistence(timeout: 2)
            }
        )
        XCTAssertTrue(
            ["Reading, Volume 8", "Lectura, Tomo 8"].contains {
                app.staticTexts[$0].waitForExistence(timeout: 2)
            }
        )

        let editCollection = app.buttons["collection.entry.edit.2"]
        for _ in 0..<4 where editCollection.exists == false {
            detail.swipeUp()
        }
        XCTAssertTrue(editCollection.waitForExistence(timeout: 2))
        editCollection.tap()
        XCTAssertTrue(app.buttons["collection.editor.owned.remove.12"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.textFields["collection.editor.reading-input"].value as? String, "8")
    }

    @MainActor
    func testMountedCollectionDetailUpdatesWithoutReselection() throws {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: [
            "-ui-testing",
            "-ui-testing-mounted-collection-detail",
        ])
        app.launch()

        let row = app.descendants(matching: .any)
            .matching(identifier: "collection.row.2")
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Owned volumes: 1") || row.label.contains("Tomos en propiedad: 1"))
        XCTAssertTrue(row.label.contains("Reading volume 1") || row.label.contains("Leyendo el tomo 1"))
        row.tap()

        let detail = app.descendants(matching: .any)["manga.detail.2"]
        XCTAssertTrue(detail.waitForExistence(timeout: 2))
        XCTAssertTrue(
            ["Owned, 1", "En propiedad, 1"].contains {
                app.staticTexts[$0].waitForExistence(timeout: 2)
            }
        )

        let update = app.buttons["ui-testing.collection.apply-synchronized-state"]
        XCTAssertTrue(update.waitForExistence(timeout: 2))
        update.tap()

        XCTAssertTrue(
            ["Owned, 1 and 12", "En propiedad, 1 y 12"].contains {
                app.staticTexts[$0].waitForExistence(timeout: 5)
            }
        )
        XCTAssertTrue(
            ["Reading, Volume 8", "Lectura, Tomo 8"].contains {
                app.staticTexts[$0].waitForExistence(timeout: 2)
            }
        )
        if row.exists {
            XCTAssertTrue(row.label.contains("Owned volumes: 2") || row.label.contains("Tomos en propiedad: 2"))
            XCTAssertTrue(row.label.contains("Reading volume 8") || row.label.contains("Leyendo el tomo 8"))
        }

        let editCollection = app.buttons["collection.entry.edit.2"]
        for _ in 0..<4 where editCollection.exists == false {
            detail.swipeUp()
        }
        XCTAssertTrue(editCollection.waitForExistence(timeout: 2))
        editCollection.tap()
        XCTAssertTrue(app.buttons["collection.editor.owned.remove.12"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.textFields["collection.editor.reading-input"].value as? String, "8")
    }

    @MainActor
    func testCollectionAuthorizationFailureKeepsTheAccountSignedIn() throws {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: [
            "-ui-testing",
            "-ui-testing-collection-authorization-denied",
        ])
        app.launch()

        let accountTab = app.buttons.matching(identifier: "tab.account").firstMatch
        XCTAssertTrue(accountTab.waitForExistence(timeout: 5))
        accountTab.tap()

        let signInAction = app.descendants(matching: .any)
            .matching(identifier: "account.sign-in.action")
            .firstMatch
        XCTAssertTrue(signInAction.waitForExistence(timeout: 2))
        signInAction.tap()

        let email = app.textFields["account.sign-in.email"]
        XCTAssertTrue(email.waitForExistence(timeout: 2))
        email.tap()
        email.typeText("ui-collection-auth@example.invalid")

        let password = app.secureTextFields["account.sign-in.password"]
        XCTAssertTrue(password.waitForExistence(timeout: 2))
        password.tap()
        password.typeText("synthetic-passphrase")
        app.buttons["account.sign-in.submit"].tap()

        let notice = app.descendants(matching: .any)["account.collection-sync.authorization-denied"]
        XCTAssertTrue(notice.waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["account.authenticated"].exists)
        XCTAssertTrue(app.buttons["account.sign-out"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["account.authentication-required"].exists)
        XCTAssertFalse(signInAction.exists)

        let collectionTab = app.buttons.matching(identifier: "tab.collection").firstMatch
        XCTAssertTrue(collectionTab.waitForExistence(timeout: 2))
        collectionTab.tap()
        XCTAssertTrue(app.descendants(matching: .any)["collection.empty"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.descendants(matching: .any)["collection.read-only"].exists)
    }

    @MainActor
    func testBlockedCollectionOutcomesCanBeReviewedCancelledAndAccepted() throws {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: [
            "-ui-testing",
            "-ui-testing-blocked-outcome-resolution",
        ])
        app.launch()

        let accountTab = app.buttons.matching(identifier: "tab.account").firstMatch
        XCTAssertTrue(accountTab.waitForExistence(timeout: 5))
        accountTab.tap()

        let notice = app.descendants(matching: .any)["account.collection-sync.upload-outcome-unconfirmed"]
        let reviewChanges = app.buttons["account.collection-sync.review"]
        XCTAssertTrue(notice.waitForExistence(timeout: 2))
        XCTAssertTrue(reviewChanges.waitForExistence(timeout: 2))
        XCTAssertTrue(reviewChanges.isHittable)
        reviewChanges.tap()

        let update = app.descendants(matching: .any)["collection.blocked-outcomes.operation.1"]
        let deletion = app.descendants(matching: .any)["collection.blocked-outcomes.operation.2"]
        XCTAssertTrue(update.waitForExistence(timeout: 2))
        XCTAssertTrue(deletion.waitForExistence(timeout: 2))
        update.tap()

        let useCloud = app.buttons["collection.blocked-outcome.use-cloud"]
        XCTAssertTrue(useCloud.waitForExistence(timeout: 2))
        XCTAssertTrue(
            app.descendants(matching: .any)["collection.blocked-outcome.version.present"]
                .waitForExistence(timeout: 2)
        )
        useCloud.tap()

        let cancel = app.buttons.matching(identifier: "collection.blocked-outcome.cancel").firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 2))
        cancel.tap()
        XCTAssertTrue(useCloud.waitForExistence(timeout: 2))

        useCloud.tap()
        let confirm = app.buttons.matching(identifier: "collection.blocked-outcome.confirm").firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 2))
        confirm.tap()

        XCTAssertTrue(update.waitForNonExistence(timeout: 2))
        XCTAssertTrue(deletion.waitForExistence(timeout: 2))
        deletion.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["collection.blocked-outcome.version.absent"]
                .waitForExistence(timeout: 2)
        )
        let useCloudForDeletion = app.buttons["collection.blocked-outcome.use-cloud"]
        XCTAssertTrue(useCloudForDeletion.waitForExistence(timeout: 2))
        useCloudForDeletion.tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 2))
        confirm.tap()

        XCTAssertTrue(app.descendants(matching: .any)["collection.blocked-outcomes.empty"].waitForExistence(timeout: 2))
        let backToAccount = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(backToAccount.waitForExistence(timeout: 2))
        backToAccount.tap()
        XCTAssertTrue(reviewChanges.waitForNonExistence(timeout: 2))
        XCTAssertFalse(notice.exists)
        XCTAssertTrue(app.descendants(matching: .any)["account.authenticated"].exists)
    }

    @MainActor
    func testTransientCollectionFailureDoesNotHideBlockedOutcomeReview() throws {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: [
            "-ui-testing",
            "-ui-testing-blocked-outcome-resolution",
            "-ui-testing-collection-authorization-denied",
        ])
        app.launch()

        let accountTab = app.buttons.matching(identifier: "tab.account").firstMatch
        XCTAssertTrue(accountTab.waitForExistence(timeout: 5))
        accountTab.tap()

        let transientNotice = app.descendants(matching: .any)["account.collection-sync.authorization-denied"]
        let durableNotice = app.descendants(matching: .any)["account.collection-sync.upload-outcome-unconfirmed"]
        let reviewChanges = app.buttons["account.collection-sync.review"]

        XCTAssertTrue(transientNotice.waitForExistence(timeout: 5))
        XCTAssertTrue(durableNotice.waitForExistence(timeout: 2))
        XCTAssertTrue(reviewChanges.waitForExistence(timeout: 2))
        XCTAssertTrue(reviewChanges.isHittable)
        XCTAssertTrue(app.descendants(matching: .any)["account.authenticated"].exists)
    }

    @MainActor
    func testSyntheticAccountSignsIn() throws(any Error) {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing")
        app.launch()

        let accountTab = app.buttons.matching(identifier: "tab.account").firstMatch
        XCTAssertTrue(accountTab.waitForExistence(timeout: 5))
        accountTab.tap()

        XCTAssertTrue(app.descendants(matching: .any)["account.signed-out"].waitForExistence(timeout: 2))
        let signInAction = app.descendants(matching: .any).matching(identifier: "account.sign-in.action").firstMatch
        XCTAssertTrue(signInAction.waitForExistence(timeout: 2))

        let registerAction = app.descendants(matching: .any).matching(identifier: "account.register.action").firstMatch
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
        XCTAssertGreaterThanOrEqual(registerAction.frame.minY - registrationPrompt.frame.maxY, 12)

        signInAction.tap()

        let submit = app.buttons["account.sign-in.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 2))
        XCTAssertTrue(submit.isEnabled)
        submit.tap()

        XCTAssertTrue(app.descendants(matching: .any)["account.sign-in.email.failure"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["account.sign-in.password.failure"].waitForExistence(timeout: 2))

        let email = app.textFields["account.sign-in.email"]
        XCTAssertTrue(email.waitForExistence(timeout: 2))
        email.tap()
        email.typeText("ui-account@example.invalid")

        let password = app.secureTextFields["account.sign-in.password"]
        XCTAssertTrue(password.waitForExistence(timeout: 2))
        password.tap()
        password.typeText("synthetic-passphrase")

        let passwordVisibility = app.buttons["account.sign-in.password-visibility"]
        XCTAssertTrue(passwordVisibility.waitForExistence(timeout: 2))
        XCTAssertTrue(passwordVisibility.isHittable)
        XCTAssertGreaterThanOrEqual(passwordVisibility.frame.width, 44)
        XCTAssertGreaterThanOrEqual(passwordVisibility.frame.height, 44)
        passwordVisibility.tap()

        let revealedPassword = app.textFields["account.sign-in.password"]
        XCTAssertTrue(revealedPassword.waitForExistence(timeout: 2))
        XCTAssertEqual(revealedPassword.value as? String, "synthetic-passphrase")
        revealedPassword.typeText("-visible")
        XCTAssertEqual(revealedPassword.value as? String, "synthetic-passphrase-visible")
        let hidePassword = app.buttons["account.sign-in.password-visibility"]
        XCTAssertTrue(hidePassword.waitForExistence(timeout: 2))
        XCTAssertTrue(hidePassword.isHittable)
        hidePassword.tap()
        let remaskedPassword = app.secureTextFields["account.sign-in.password"]
        XCTAssertTrue(remaskedPassword.waitForExistence(timeout: 2))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))

        app.buttons["account.sign-in.password-visibility"].tap()
        let revealedAfterRemask = app.textFields["account.sign-in.password"]
        XCTAssertTrue(revealedAfterRemask.waitForExistence(timeout: 2))
        XCTAssertEqual(revealedAfterRemask.value as? String, "synthetic-passphrase-visible")
        revealedAfterRemask.typeText("-hidden")
        XCTAssertEqual(revealedAfterRemask.value as? String, "synthetic-passphrase-visible-hidden")
        app.buttons["account.sign-in.password-visibility"].tap()
        XCTAssertTrue(app.secureTextFields["account.sign-in.password"].waitForExistence(timeout: 2))

        email.tap()
        app.buttons["account.sign-in.password-visibility"].tap()
        let revealedAfterUnfocusedToggle = app.textFields["account.sign-in.password"]
        XCTAssertTrue(revealedAfterUnfocusedToggle.waitForExistence(timeout: 2))
        XCTAssertEqual(revealedAfterUnfocusedToggle.value as? String, "synthetic-passphrase-visible-hidden")
        revealedAfterUnfocusedToggle.tap()
        app.buttons["account.sign-in.password-visibility"].tap()
        let remaskedAfterRefocus = app.secureTextFields["account.sign-in.password"]
        XCTAssertTrue(remaskedAfterRefocus.waitForExistence(timeout: 2))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))

        XCTAssertTrue(submit.isHittable)
        XCTAssertGreaterThanOrEqual(submit.frame.width, 44)
        XCTAssertGreaterThanOrEqual(submit.frame.height, 44)
        submit.tap()
        let authenticated = app.descendants(matching: .any)["account.authenticated"]
        XCTAssertTrue(authenticated.waitForExistence(timeout: 2))

        let identityEmail = app.descendants(matching: .any)["account.identity.email"]
        XCTAssertTrue(identityEmail.waitForExistence(timeout: 2))
        XCTAssertTrue(identityEmail.label.contains("reader@example.invalid"))
        XCTAssertFalse(identityEmail.label.contains("ui-account@example.invalid"))

        let signOut = app.buttons["account.sign-out"]
        XCTAssertTrue(signOut.waitForExistence(timeout: 2))
        XCTAssertTrue(signOut.isHittable)
        XCTAssertGreaterThanOrEqual(signOut.frame.width, 44)
        XCTAssertGreaterThanOrEqual(signOut.frame.height, 44)
    }

    @MainActor
    func testSyntheticAccountRegistrationSignsIn() throws(any Error) {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing")
        app.launch()

        let accountTab = app.buttons.matching(identifier: "tab.account").firstMatch
        XCTAssertTrue(accountTab.waitForExistence(timeout: 5))
        accountTab.tap()

        let registerAction = app.descendants(matching: .any).matching(identifier: "account.register.action").firstMatch
        XCTAssertTrue(registerAction.waitForExistence(timeout: 2))
        registerAction.tap()

        let submit = app.buttons["account.register.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 2))
        XCTAssertTrue(submit.isEnabled)
        submit.tap()

        XCTAssertTrue(app.descendants(matching: .any)["account.register.email.failure"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["account.register.password.failure"].waitForExistence(timeout: 2))

        let email = app.textFields["account.register.email"]
        XCTAssertTrue(email.waitForExistence(timeout: 2))
        email.tap()
        email.typeText("ui-new-account@example.invalid")

        let password = app.secureTextFields["account.register.password"]
        XCTAssertTrue(password.waitForExistence(timeout: 2))
        password.tap()

        let dismissStrongPasswordSuggestion = app.buttons.matching(identifier: "xmark").firstMatch
        if dismissStrongPasswordSuggestion.waitForExistence(timeout: 1) {
            dismissStrongPasswordSuggestion.tap()
            password.tap()
        }
        password.typeText("synthetic-passphrase")

        let passwordVisibility = app.buttons["account.register.password-visibility"]
        XCTAssertTrue(passwordVisibility.waitForExistence(timeout: 2))
        XCTAssertTrue(passwordVisibility.isHittable)
        XCTAssertGreaterThanOrEqual(passwordVisibility.frame.width, 44)
        XCTAssertGreaterThanOrEqual(passwordVisibility.frame.height, 44)
        passwordVisibility.tap()

        let revealedPassword = app.textFields["account.register.password"]
        XCTAssertTrue(revealedPassword.waitForExistence(timeout: 2))
        XCTAssertEqual(revealedPassword.value as? String, "synthetic-passphrase")
        revealedPassword.typeText("-visible")
        XCTAssertEqual(revealedPassword.value as? String, "synthetic-passphrase-visible")
        let hidePassword = app.buttons["account.register.password-visibility"]
        XCTAssertTrue(hidePassword.waitForExistence(timeout: 2))
        XCTAssertTrue(hidePassword.isHittable)
        hidePassword.tap()
        let remaskedPassword = app.secureTextFields["account.register.password"]
        XCTAssertTrue(remaskedPassword.waitForExistence(timeout: 2))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))

        app.buttons["account.register.password-visibility"].tap()
        let revealedAfterRemask = app.textFields["account.register.password"]
        XCTAssertTrue(revealedAfterRemask.waitForExistence(timeout: 2))
        XCTAssertEqual(revealedAfterRemask.value as? String, "synthetic-passphrase-visible")
        revealedAfterRemask.typeText("-hidden")
        XCTAssertEqual(revealedAfterRemask.value as? String, "synthetic-passphrase-visible-hidden")
        app.buttons["account.register.password-visibility"].tap()
        XCTAssertTrue(app.secureTextFields["account.register.password"].waitForExistence(timeout: 2))

        email.tap()
        app.buttons["account.register.password-visibility"].tap()
        let revealedAfterUnfocusedToggle = app.textFields["account.register.password"]
        XCTAssertTrue(revealedAfterUnfocusedToggle.waitForExistence(timeout: 2))
        XCTAssertEqual(revealedAfterUnfocusedToggle.value as? String, "synthetic-passphrase-visible-hidden")
        revealedAfterUnfocusedToggle.tap()
        app.buttons["account.register.password-visibility"].tap()
        let remaskedAfterRefocus = app.secureTextFields["account.register.password"]
        XCTAssertTrue(remaskedAfterRefocus.waitForExistence(timeout: 2))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))

        XCTAssertTrue(submit.isHittable)
        XCTAssertGreaterThanOrEqual(submit.frame.width, 44)
        XCTAssertGreaterThanOrEqual(submit.frame.height, 44)
        submit.tap()
        let authenticated = app.descendants(matching: .any)["account.authenticated"]
        XCTAssertTrue(authenticated.waitForExistence(timeout: 5))

        let identityEmail = app.descendants(matching: .any)["account.identity.email"]
        XCTAssertTrue(identityEmail.waitForExistence(timeout: 2))
        XCTAssertTrue(identityEmail.label.contains("reader@example.invalid"))
        XCTAssertFalse(identityEmail.label.contains("ui-new-account@example.invalid"))
    }
}
