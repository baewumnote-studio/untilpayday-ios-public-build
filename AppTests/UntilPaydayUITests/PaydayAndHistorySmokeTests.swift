import XCTest

final class PaydayAndHistorySmokeTests: XCTestCase {
    func testPaydayShowsBannerInsteadOfBlockingSheet() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing-payday", "YES"]
        app.launch()

        XCTAssertTrue(app.staticTexts["It's payday"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Start new pay cycle"].exists)
        XCTAssertFalse(app.navigationBars["New pay cycle"].exists)
    }

    func testCompletedCycleOpensFromHistory() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing-history", "YES"]
        app.launch()

        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 3))

        let firstCycle = app.buttons["historyCycleCard"].firstMatch
        XCTAssertTrue(firstCycle.waitForExistence(timeout: 3))
        firstCycle.tap()

        XCTAssertTrue(app.navigationBars["Pay cycle"].waitForExistence(timeout: 3))
    }
}
