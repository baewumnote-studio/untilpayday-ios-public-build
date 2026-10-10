import XCTest

final class VisualMasterNavigationTests: XCTestCase {
    func testMainTabBarUsesFourTabStructure() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing-seeded", "YES"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 3))
        XCTAssertTrue(tabBar.buttons["Today"].exists)
        XCTAssertTrue(tabBar.buttons["Plan"].exists)
        XCTAssertTrue(tabBar.buttons["History"].exists)
        XCTAssertTrue(tabBar.buttons["Settings"].exists)
    }

    func testSettingsShowsLocalBudgetTrustMessage() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing-seeded", "YES"]
        app.launch()

        app.tabBars.buttons["Settings"].tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Your budget. Your device."].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["No bank connection"].exists)
        XCTAssertTrue(app.staticTexts["No account required"].exists)
    }

    func testPlanUsesUpcomingAndRecurringSegments() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing-seeded", "YES"]
        app.launch()

        app.tabBars.buttons["Plan"].tap()

        XCTAssertTrue(app.navigationBars["Plan"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Upcoming"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Recurring"].exists)
    }
}
