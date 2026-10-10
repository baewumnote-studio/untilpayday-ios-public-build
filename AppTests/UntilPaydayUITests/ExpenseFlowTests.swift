import XCTest

@MainActor
final class ExpenseFlowTests: XCTestCase {
    func testExpenseCanBeAddedFromToday() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing-seeded", "YES"]
        app.launch()

        XCTAssertTrue(app.buttons["Add expense"].waitForExistence(timeout: 3))
        app.buttons["Add expense"].tap()

        XCTAssertTrue(app.navigationBars["Add expense"].waitForExistence(timeout: 3))

        let amount = app.textFields["moneyAmountField"]
        XCTAssertTrue(amount.waitForExistence(timeout: 2))
        amount.tap()
        amount.typeText("25.50")

        app.buttons["Save expense"].tap()
        XCTAssertTrue(app.buttons["Add expense"].waitForExistence(timeout: 3))
        let savedExpense = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ AND value CONTAINS %@",
                                  "safeTodayCard", "$25.50 spent today"))
            .firstMatch
        XCTAssertTrue(savedExpense.waitForExistence(timeout: 3),
                      "Safe Today must reflect the saved $25.50 expense")
    }
}
