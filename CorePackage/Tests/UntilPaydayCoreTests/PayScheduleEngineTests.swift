import XCTest
@testable import UntilPaydayCore

final class PayScheduleEngineTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    func testDaysRemainingOct7ToOct20Is13() {
        XCTAssertEqual(PayScheduleEngine.daysRemaining(from: date(2026, 10, 7), to: date(2026, 10, 20), calendar: calendar), 13)
    }

    func testDaysRemainingAcrossDSTUsesCalendarDays() {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        let start = newYork.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        let end = newYork.date(from: DateComponents(year: 2026, month: 3, day: 9))!
        XCTAssertEqual(PayScheduleEngine.daysRemaining(from: start, to: end, calendar: newYork), 2)
    }

    func testWeeklyIsSevenDays() throws {
        let config = PayScheduleConfiguration(type: .weekly, anchorPayday: date(2026, 10, 2))
        let next = try PayScheduleEngine.nextPayday(onOrAfter: date(2026, 10, 3), configuration: config, calendar: calendar)
        XCTAssertEqual(next, date(2026, 10, 9))
    }

    func testBiweeklyIsExactlyFourteenDays() throws {
        let config = PayScheduleConfiguration(type: .biweekly, anchorPayday: date(2026, 10, 2))
        let next = try PayScheduleEngine.nextPayday(onOrAfter: date(2026, 10, 3), configuration: config, calendar: calendar)
        XCTAssertEqual(next, date(2026, 10, 16))
    }

    func testSemiMonthlyFirstAndFifteenth() throws {
        let config = PayScheduleConfiguration(type: .semiMonthly, semiMonthlyFirstRule: .fixed(1), semiMonthlySecondRule: .fixed(15))
        XCTAssertEqual(try PayScheduleEngine.nextPayday(onOrAfter: date(2026, 10, 2), configuration: config, calendar: calendar), date(2026, 10, 15))
        XCTAssertEqual(try PayScheduleEngine.nextPayday(onOrAfter: date(2026, 10, 16), configuration: config, calendar: calendar), date(2026, 11, 1))
    }

    func testSemiMonthlyFifteenthAndLastDay() throws {
        let config = PayScheduleConfiguration(type: .semiMonthly, semiMonthlyFirstRule: .fixed(15), semiMonthlySecondRule: .lastDay)
        XCTAssertEqual(try PayScheduleEngine.nextPayday(onOrAfter: date(2026, 2, 16), configuration: config, calendar: calendar), date(2026, 2, 28))
    }

    func testLeapYearLastDay() throws {
        let config = PayScheduleConfiguration(type: .monthly, monthlyRule: .lastDay)
        XCTAssertEqual(try PayScheduleEngine.nextPayday(onOrAfter: date(2028, 2, 2), configuration: config, calendar: calendar), date(2028, 2, 29))
    }

    func testMonthly31ClampsToFebruary() throws {
        let config = PayScheduleConfiguration(type: .monthly, monthlyRule: .fixed(31))
        XCTAssertEqual(try PayScheduleEngine.nextPayday(onOrAfter: date(2026, 2, 1), configuration: config, calendar: calendar), date(2026, 2, 28))
    }

    func testPreviousWeekdayAdjustment() throws {
        let config = PayScheduleConfiguration(type: .monthly, monthlyRule: .fixed(10), weekendAdjustment: .previousWeekday)
        // Jan 10, 2026 is Saturday.
        XCTAssertEqual(try PayScheduleEngine.nextPayday(onOrAfter: date(2026, 1, 1), configuration: config, calendar: calendar), date(2026, 1, 9))
    }

    func testNextWeekdayAdjustment() throws {
        let config = PayScheduleConfiguration(type: .monthly, monthlyRule: .fixed(10), weekendAdjustment: .nextWeekday)
        XCTAssertEqual(try PayScheduleEngine.nextPayday(onOrAfter: date(2026, 1, 1), configuration: config, calendar: calendar), date(2026, 1, 12))
    }

    func testWeekendAdjustmentDoesNotChangeMonthlyNominalRule() throws {
        let config = PayScheduleConfiguration(type: .monthly, monthlyRule: .fixed(10), weekendAdjustment: .previousWeekday)
        let january = try PayScheduleEngine.nextPayday(onOrAfter: date(2026, 1, 1), configuration: config, calendar: calendar)
        XCTAssertEqual(january, date(2026, 1, 9))
        let february = try PayScheduleEngine.nextPayday(onOrAfter: date(2026, 2, 1), configuration: config, calendar: calendar)
        XCTAssertEqual(february, date(2026, 2, 10))
    }

    func testOccurrencePreservesNominalDateWhenWeekendAdjusted() throws {
        let config = PayScheduleConfiguration(type: .monthly, monthlyRule: .fixed(10), weekendAdjustment: .previousWeekday)
        let occurrence = try PayScheduleEngine.nextOccurrence(onOrAfter: date(2026, 1, 1), configuration: config, calendar: calendar)
        XCTAssertEqual(occurrence.nominalDate, date(2026, 1, 10))
        XCTAssertEqual(occurrence.adjustedDate, date(2026, 1, 9))
        let next = try PayScheduleEngine.nextOccurrence(onOrAfter: date(2026, 1, 11), configuration: config, calendar: calendar)
        XCTAssertEqual(next.nominalDate, date(2026, 2, 10))
        XCTAssertEqual(next.adjustedDate, date(2026, 2, 10))
    }

    func testIrregularPayday() throws {
        let config = PayScheduleConfiguration(type: .irregular, manualNextPayday: date(2026, 10, 20))
        XCTAssertEqual(try PayScheduleEngine.nextPayday(onOrAfter: date(2026, 10, 7), configuration: config, calendar: calendar), date(2026, 10, 20))
    }
}

extension PayScheduleEngineTests {
    func testPreviousWeekdayAdjustmentDoesNotReturnPastPaydayWhenOpenedOnNominalSaturday() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let anchor = calendar.date(from: DateComponents(year: 2026, month: 10, day: 10))! // Saturday
        let configuration = PayScheduleConfiguration(
            type: .weekly,
            anchorPayday: anchor,
            weekendAdjustment: .previousWeekday
        )

        let occurrence = try PayScheduleEngine.nextOccurrence(
            onOrAfter: anchor,
            configuration: configuration,
            calendar: calendar
        )

        XCTAssertEqual(calendar.component(.day, from: occurrence.nominalDate), 17)
        XCTAssertEqual(calendar.component(.day, from: occurrence.adjustedDate), 16)
        XCTAssertGreaterThanOrEqual(occurrence.adjustedDate, anchor)
    }
}

extension PayScheduleEngineTests {
    func testSemiMonthlyRejectsDuplicateRules() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let reference = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))!
        let configuration = PayScheduleConfiguration(
            type: .semiMonthly,
            semiMonthlyFirstRule: .fixed(15),
            semiMonthlySecondRule: .fixed(15)
        )

        XCTAssertThrowsError(
            try PayScheduleEngine.nextPayday(
                onOrAfter: reference,
                configuration: configuration,
                calendar: calendar
            )
        ) { error in
            XCTAssertEqual(error as? PayScheduleError, .invalidDayRule)
        }
    }
}

extension PayScheduleEngineTests {
    func testSemiMonthlyRejectsRulesThatCollapseAtMonthEnd() {
        let configuration = PayScheduleConfiguration(
            type: .semiMonthly,
            semiMonthlyFirstRule: .fixed(30),
            semiMonthlySecondRule: .fixed(31)
        )

        XCTAssertThrowsError(
            try PayScheduleEngine.nextPayday(
                onOrAfter: date(2026, 2, 1),
                configuration: configuration,
                calendar: calendar
            )
        ) { error in
            XCTAssertEqual(error as? PayScheduleError, .invalidDayRule)
        }
    }

    func testFixedDayAboveThirtyOneIsRejected() {
        let configuration = PayScheduleConfiguration(
            type: .monthly,
            monthlyRule: .fixed(32)
        )

        XCTAssertThrowsError(
            try PayScheduleEngine.nextPayday(
                onOrAfter: date(2026, 2, 1),
                configuration: configuration,
                calendar: calendar
            )
        ) { error in
            XCTAssertEqual(error as? PayScheduleError, .invalidDayRule)
        }
    }
}
