import XCTest

final class OnboardingSmokeTests: XCTestCase {
    func testFirstLaunchShowsCorePromise() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing-reset", "YES"]
        app.launch()

        XCTAssertTrue(
            app.staticTexts["Make your money\nlast until payday."].waitForExistence(timeout: 3)
            || app.staticTexts["Make your money last until payday."].waitForExistence(timeout: 1)
        )
        XCTAssertTrue(app.buttons["Get started"].exists)
    }
}
