import XCTest

// Assembly verification only. Exercises the real embedded WidgetKit extension
// through SpringBoard; it does not change the supplied application or widget.
@MainActor
final class ZZWidgetRuntimeTests: XCTestCase {
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    private func capture(_ name: String) {
        print("Widget runtime checkpoint: " + name)
        print(springboard.debugDescription)
        let screenshot = XCTAttachment(screenshot: springboard.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let tree = XCTAttachment(string: springboard.debugDescription)
        tree.name = name + "_accessibility"
        tree.lifetime = .keepAlways
        add(tree)
    }

    private func tapLabel(_ label: String, timeout: TimeInterval = 10) -> Bool {
        let element = springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "label MATCHES %@", "\\s*" + NSRegularExpression.escapedPattern(for: label) + "\\s*")).firstMatch
        guard element.waitForExistence(timeout: timeout) else {
            capture("Missing_" + label)
            XCTFail("SpringBoard control missing: " + label)
            return false
        }
        element.tap()
        return true
    }

    private func widgetAmount(_ amount: String) -> XCUIElement {
        springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@ AND label CONTAINS %@", "SAFE TODAY", amount))
            .firstMatch
    }

    func testHomeWidgetReadsAppGroupUpdatesAndOpensToday() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-visual-master", "YES"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "safeTodayCard").firstMatch.waitForExistence(timeout: 10))
        XCUIDevice.shared.press(.home)
        let icon = springboard.icons["Payday Left"].firstMatch
        guard icon.waitForExistence(timeout: 15) else {
            capture("Missing_App_Icon")
            XCTFail("Payday Left icon missing from Home Screen")
            return
        }
        icon.press(forDuration: 1.5)
        guard tapLabel("Edit Home Screen") else { return }
        guard tapLabel("Edit") else { return }
        let search = springboard.searchFields["Search Widgets"].firstMatch
        // The observed iOS 27 Edit button opens the gallery directly. Other
        // runtimes expose an Add Widget menu before the same gallery.
        if !search.waitForExistence(timeout: 3) {
            guard tapLabel("Add Widget") else { return }
        }
        guard search.waitForExistence(timeout: 10) else {
            capture("Missing_Widget_Search")
            XCTFail("Widget gallery search missing")
            return
        }
        search.tap()
        search.typeText("Payday Left")
        let listing = springboard.cells.matching(NSPredicate(format: "label == %@", "Payday Left")).firstMatch
        guard listing.waitForExistence(timeout: 10) else {
            capture("Missing_Widget_Gallery_Listing")
            XCTFail("Payday Left listing missing from widget gallery")
            return
        }
        listing.tap()
        guard tapLabel("Add Widget") else { return }
        guard tapLabel("Done") else { return }
        capture("Widget_Added")
        XCTAssertTrue(widgetAmount("52.00").waitForExistence(timeout: 30), "Widget must read the seeded $52 Safe Today from the app's App Group")
        capture("Widget_Seeded_52")
        widgetAmount("52.00").tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "safeTodayCard").firstMatch.waitForExistence(timeout: 10), "Widget URL must open Today")

        // Resume, rather than relaunch: the supplied seed launch argument resets
        // the sample data on each launch. Saving this expense reloads timelines.
        app.buttons["Add expense"].tap()
        let amount = app.textFields["moneyAmountField"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("25.50")
        app.buttons["Save expense"].tap()
        XCTAssertTrue(app.buttons["Add expense"].waitForExistence(timeout: 10))
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(widgetAmount("26.50").waitForExistence(timeout: 60), "Real widget must refresh after app saves a $25.50 expense")
        capture("Widget_Updated_26_50")
    }
}
