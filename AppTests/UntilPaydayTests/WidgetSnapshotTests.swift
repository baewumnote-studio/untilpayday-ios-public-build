import XCTest
@testable import UntilPayday

final class WidgetSnapshotTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testSnapshotRoundTripsCodable() throws {
        let original = SharedWidgetSnapshot(
            freeNowMinor: 123_400,
            todayFlexibleSpentMinor: 2_000,
            currencyCode: "USD",
            nextPayday: Date(timeIntervalSince1970: 1_800_086_400),
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SharedWidgetSnapshot.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testSameDayWidgetPreservesSafeTodayRemaining() {
        let c = calendar
        let today = c.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 12))!
        let payday = c.date(from: DateComponents(year: 2026, month: 10, day: 20))!
        let snapshot = SharedWidgetSnapshot(
            freeNowMinor: 126_000,
            todayFlexibleSpentMinor: 4_000,
            currencyCode: "USD",
            nextPayday: payday,
            generatedAt: today
        )

        let values = WidgetBudgetCalculator.calculate(snapshot: snapshot, at: today, calendar: c)
        XCTAssertEqual(values.daysRemaining, 13)
        XCTAssertEqual(values.safeMinor, 6_000)
    }

    func testNextDayRedistributesUnusedMoneyAndClearsYesterdaySpend() {
        let c = calendar
        let generated = c.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 12))!
        let nextDay = c.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: 8))!
        let payday = c.date(from: DateComponents(year: 2026, month: 10, day: 20))!
        let snapshot = SharedWidgetSnapshot(
            freeNowMinor: 126_000,
            todayFlexibleSpentMinor: 4_000,
            currencyCode: "USD",
            nextPayday: payday,
            generatedAt: generated
        )

        let values = WidgetBudgetCalculator.calculate(snapshot: snapshot, at: nextDay, calendar: c)
        XCTAssertEqual(values.daysRemaining, 12)
        XCTAssertEqual(values.safeMinor, 10_500)
    }

    func testDeficitShowsShortByInsteadOfNegativeSafeAmount() {
        let c = calendar
        let today = c.date(from: DateComponents(year: 2026, month: 10, day: 7))!
        let payday = c.date(from: DateComponents(year: 2026, month: 10, day: 10))!
        let snapshot = SharedWidgetSnapshot(
            freeNowMinor: -12_800,
            todayFlexibleSpentMinor: 0,
            currencyCode: "USD",
            nextPayday: payday,
            generatedAt: today
        )

        let values = WidgetBudgetCalculator.calculate(snapshot: snapshot, at: today, calendar: c)
        XCTAssertEqual(values.safeMinor, 0)
        XCTAssertEqual(values.shortByMinor, 12_800)
    }

    func testPaydayStateDoesNotDivideByZero() {
        let c = calendar
        let today = c.date(from: DateComponents(year: 2026, month: 10, day: 20))!
        let snapshot = SharedWidgetSnapshot(
            freeNowMinor: 14_200,
            todayFlexibleSpentMinor: 0,
            currencyCode: "USD",
            nextPayday: today,
            generatedAt: today
        )

        let values = WidgetBudgetCalculator.calculate(snapshot: snapshot, at: today, calendar: c)
        XCTAssertTrue(values.isPayday)
        XCTAssertEqual(values.daysRemaining, 0)
        XCTAssertEqual(values.safeMinor, 0)
        XCTAssertEqual(values.leftMinor, 14_200)
    }
}
