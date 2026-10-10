import XCTest

@MainActor
final class VisualMasterScreenshotSmokeTests: XCTestCase {
    private func launchSeededApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing-visual-master", "YES"]
        app.launch()
        return app
    }

    func testTodayVisualMasterStateIsScreenshotReady() {
        let app = launchSeededApp()

        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "paydaySummary").firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["leftUntilPaydayHero"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "safeTodayCard").firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Add expense"].exists)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "01_Today_Visual_Master"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testPlanVisualMasterStateIsScreenshotReady() {
        let app = launchSeededApp()
        app.tabBars.buttons["Plan"].tap()

        XCTAssertTrue(app.navigationBars["Plan"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.segmentedControls["planSegmentedControl"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Electricity"].exists)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "02_Plan_Visual_Master"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSettingsTrustStateIsScreenshotReady() {
        let app = launchSeededApp()
        app.tabBars.buttons["Settings"].tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "trustSummaryCard").firstMatch.waitForExistence(timeout: 2))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "06_Settings_Trust"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
