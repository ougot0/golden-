import XCTest

/// Launches the app with `-ui-testing` (in-memory store, isolated settings, fixed place: Paris),
/// so these tests never trigger the location permission prompt.
final class GoldenHourUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
    }

    func testDashboardShowsSolarSections() {
        XCTAssertTrue(app.buttons["placeButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Heures dorées et bleues"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Lever"].exists)
        XCTAssertTrue(app.staticTexts["Coucher"].exists)
    }

    func testDayNavigation() {
        let next = app.buttons["Jour suivant"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        next.tap()
        // Leaving today reveals the "Aujourd'hui" shortcut.
        let todayButton = app.buttons["Aujourd'hui"].firstMatch
        XCTAssertTrue(todayButton.waitForExistence(timeout: 2))
    }

    func testAllTabsOpen() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        tabBar.buttons["Calendrier"].tap()
        XCTAssertTrue(app.navigationBars["Calendrier"].waitForExistence(timeout: 3))
        tabBar.buttons["Boussole"].tap()
        XCTAssertTrue(app.navigationBars["Boussole solaire"].waitForExistence(timeout: 3))
        tabBar.buttons["Séances"].tap()
        XCTAssertTrue(app.navigationBars["Séances"].waitForExistence(timeout: 3))
        tabBar.buttons["Réglages"].tap()
        XCTAssertTrue(app.navigationBars["Réglages"].waitForExistence(timeout: 3))
    }

    func testCreateSession() {
        app.tabBars.firstMatch.buttons["Séances"].tap()
        app.buttons["newSession"].tap()
        let title = app.textFields["sessionTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        title.tap()
        title.typeText("Pont des Arts")
        app.buttons["saveSession"].tap()
        XCTAssertTrue(app.staticTexts["Pont des Arts"].waitForExistence(timeout: 3))
    }

    func testSettingsPagesOpen() {
        app.tabBars.firstMatch.buttons["Réglages"].tap()
        for page in ["Précision des calculs", "Confidentialité", "À propos"] {
            app.buttons[page].tap()
            XCTAssertTrue(app.navigationBars[page].waitForExistence(timeout: 3), page)
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
    }
}
