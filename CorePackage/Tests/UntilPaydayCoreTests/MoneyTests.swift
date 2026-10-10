import XCTest
@testable import UntilPaydayCore

final class MoneyTests: XCTestCase {
    func testCurrencyCodeIsNormalized() {
        let money = Money(minorUnits: 1_025, currencyCode: "usd")
        XCTAssertEqual(money.currencyCode, "USD")
    }

    func testAdditionUsesIntegerMinorUnits() throws {
        let a = Money(minorUnits: 1_025, currencyCode: "USD")
        let b = Money(minorUnits: 2_075, currencyCode: "USD")
        XCTAssertEqual(try a.adding(b).minorUnits, 3_100)
    }

    func testCurrencyMismatchThrows() {
        let usd = Money(minorUnits: 100, currencyCode: "USD")
        let cad = Money(minorUnits: 100, currencyCode: "CAD")
        XCTAssertThrowsError(try usd.adding(cad)) { error in
            XCTAssertEqual(error as? MoneyError, .currencyMismatch(expected: "USD", received: "CAD"))
        }
    }

    func testOverflowThrows() {
        let max = Money(minorUnits: .max, currencyCode: "USD")
        let one = Money(minorUnits: 1, currencyCode: "USD")
        XCTAssertThrowsError(try max.adding(one)) { error in
            XCTAssertEqual(error as? MoneyError, .overflow)
        }
    }
}
