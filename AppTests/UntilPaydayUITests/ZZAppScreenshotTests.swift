import XCTest

// Captures the supplied application running in Simulator. No product changes.
@MainActor
final class ZZAppScreenshotTests: XCTestCase {
    private func capture(_ app: XCUIApplication, _ name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = name + "_accessibility"
        tree.lifetime = .keepAlways
        add(tree)
        print("App screenshot captured: " + name)
    }

    func testCaptureActualAppScreens() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-visual-master", "YES"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "safeTodayCard").firstMatch.waitForExistence(timeout: 15))
        capture(app, "01_Today_Actual")

        app.buttons["Add expense"].tap()
        XCTAssertTrue(app.textFields["moneyAmountField"].waitForExistence(timeout: 5))
        capture(app, "02_Add_Expense_Actual")
        app.buttons["Cancel"].tap()

        app.tabBars.buttons["Plan"].tap()
        XCTAssertTrue(app.navigationBars["Plan"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls["planSegmentedControl"].waitForExistence(timeout: 5))
        capture(app, "03_Plan_Upcoming_Actual")
        app.segmentedControls["planSegmentedControl"].buttons["Recurring"].tap()
        capture(app, "04_Plan_Recurring_Actual")

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        capture(app, "05_Settings_Actual")
        let privacy = app.buttons["Privacy policy"]
        for _ in 0..<5 {
            if privacy.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(privacy.isHittable)
        privacy.tap()
        XCTAssertTrue(app.navigationBars["Privacy policy"].waitForExistence(timeout: 5))
        capture(app, "06_Privacy_Policy_Actual")
    }
}
