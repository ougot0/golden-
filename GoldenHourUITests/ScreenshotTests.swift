import XCTest

/// Captures App Store screenshots. Run explicitly (the CI "screenshots" job does it on an
/// iPhone 6.9″ simulator, in light and dark appearance):
///   xcodebuild test -only-testing:GoldenHourUITests/ScreenshotTests …
/// Screens show real computed data for the fixed UI-test place (Paris) on the day of the run;
/// the only content typed in is the session created through the interface.
final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
        app = XCUIApplication()
        // French App Store screenshots: French language and region (24-hour clock, Monday first).
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        app.launch()
    }

    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testCaptureScreens() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))

        // 1–2. Dashboard: countdown and sun position, then timeline and golden/blue hours.
        XCTAssertTrue(app.staticTexts["Heures dorées et bleues"].waitForExistence(timeout: 10))
        snapshot("01-Aujourdhui")
        // Half-screen drag so the second capture shows the middle of the page, not the bottom.
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)))
        sleep(1)
        snapshot("02-Heures")

        // 3. Calendar, month view.
        tabBar.buttons["Calendrier"].tap()
        sleep(2)
        snapshot("04-Calendrier")
        app.buttons["Semaine"].tap()
        sleep(2)
        snapshot("05-Semaine")

        // 4. Compass.
        tabBar.buttons["Boussole"].tap()
        sleep(2)
        snapshot("06-Boussole")

        // 5. Session planning: create one through the interface.
        tabBar.buttons["Séances"].tap()
        app.buttons["newSession"].tap()
        let title = app.textFields["sessionTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Pont Alexandre III\n")  // return dismisses the keyboard
        sleep(1)
        snapshot("07-NouvelleSeance")
        app.buttons["saveSession"].tap()
        XCTAssertTrue(app.staticTexts["Pont Alexandre III"].waitForExistence(timeout: 5))
        app.staticTexts["Pont Alexandre III"].tap()
        sleep(1)
        snapshot("08-Seance")

        // 6. Accuracy page.
        tabBar.buttons["Réglages"].tap()
        app.buttons["Précision des calculs"].tap()
        sleep(1)
        snapshot("09-Precision")
    }
}
