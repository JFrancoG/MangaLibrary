import XCTest

final class AppStartupUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testStartupRecoveryInEnglish() throws {
        try assertStartupRecovery(language: "en", locale: "en_US", usesLargestText: false)
    }

    @MainActor
    func testStartupRecoveryInSpanishWithLargestText() throws {
        try assertStartupRecovery(language: "es", locale: "es_ES", usesLargestText: true)
    }

    @MainActor
    private func assertStartupRecovery(language: String, locale: String, usesLargestText: Bool) throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-ui-testing-startup-recovery",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale,
        ]
        if usesLargestText {
            app.launchArguments += [
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
            ]
        }
        app.launch()

        let retry = app.buttons["startup.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        let title = language == "es" ? "No se ha podido abrir tu biblioteca" : "Your library couldn’t be opened"
        XCTAssertTrue(app.staticTexts[title].exists)
        XCTAssertEqual(retry.label, language == "es" ? "Volver a intentar" : "Try again")
        XCTAssertFalse(app.descendants(matching: .any)["catalog.row.1"].exists)

        for _ in 0..<3 where !retry.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(retry.isHittable)
        let failure = XCTAttachment(screenshot: app.screenshot())
        failure.name = "Startup recovery \(language)"
        failure.lifetime = .keepAlways
        add(failure)

        retry.tap()

        XCTAssertTrue(retry.waitForNonExistence(timeout: 2))
        let firstManga = app.descendants(matching: .any)["catalog.row.1"]
        XCTAssertTrue(firstManga.waitForExistence(timeout: 5))
        firstManga.tap()
        XCTAssertTrue(app.descendants(matching: .any)["manga.detail.1"].waitForExistence(timeout: 2))
    }
}
