import XCTest
@testable import UntilPayday

final class MoneyFormatterTests: XCTestCase {
    private let us = Locale(identifier: "en_US")

    func testUSDUsesTwoFractionDigits() {
        XCTAssertEqual(
            MoneyFormatter.string(
                minorUnits: 132_700,
                currencyCode: "USD",
                locale: us
            ),
            "$1,327.00"
        )
    }

    func testJPYUsesZeroFractionDigitsEvenInUSLocale() {
        XCTAssertEqual(
            MoneyFormatter.string(
                minorUnits: 132_700,
                currencyCode: "JPY",
                locale: us
            ),
            "¥132,700"
        )
    }

    func testParsingRespectsCurrencyMinorUnits() {
        XCTAssertEqual(
            MoneyFormatter.parseMinorUnits(
                "1327.00",
                currencyCode: "USD",
                locale: us
            ),
            132_700
        )

        XCTAssertEqual(
            MoneyFormatter.parseMinorUnits(
                "132700",
                currencyCode: "JPY",
                locale: us
            ),
            132_700
        )
    }

    func testHugeInputIsRejectedInsteadOfOverflowing() {
        XCTAssertNil(
            MoneyFormatter.parseMinorUnits(
                "999999999999999999999999",
                currencyCode: "USD",
                locale: us
            )
        )
    }
}
