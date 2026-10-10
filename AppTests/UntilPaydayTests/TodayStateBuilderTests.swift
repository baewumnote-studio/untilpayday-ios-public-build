import XCTest
import UntilPaydayCore
@testable import UntilPayday

final class TodayStateBuilderTests: XCTestCase {
    func testBuilderUsesBudgetSnapshotValuesWithoutRecalculatingUIAmounts() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 12))!
        let payday = calendar.date(from: DateComponents(year: 2026, month: 10, day: 20))!

        let cycle = PayCycle(
            startDate: now,
            endDate: payday,
            incomeMinor: 280_000,
            savingsReserveMinor: 30_000,
            currencyCode: "USD"
        )

        let budget = CycleBudgetViewModel(
            snapshot: BudgetSnapshot(
                state: .active,
                leftUntilPaydayMinor: 132_700,
                safeTodayPlanMinor: 10_000,
                safeTodayRemainingMinor: 5_200,
                shortByMinor: 0,
                overTodayPaceMinor: 0
            ),
            spentTodayMinor: 4_800,
            totalSpentMinor: 42_300,
            extraIncomeMinor: 0,
            pendingBillsMinor: 75_000,
            pendingBills: []
        )

        let state = TodayStateBuilder.make(
            cycle: cycle,
            budget: budget,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(state.daysRemaining, 13)
        XCTAssertEqual(state.leftUntilPaydayMinor, 132_700)
        XCTAssertEqual(state.safeTodayMinor, 5_200)
        XCTAssertEqual(state.todayFlexibleSpentMinor, 4_800)
        XCTAssertEqual(state.dailyPaceMinor, 10_000)
    }

    func testBuilderLimitsUpcomingBillsToThreeAndOrdersFromBudgetInput() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 7))!
        let payday = calendar.date(from: DateComponents(year: 2026, month: 10, day: 20))!
        let cycle = PayCycle(startDate: now, endDate: payday, incomeMinor: 100_000, currencyCode: "USD")

        let bills = (1...4).map { offset in
            BillOccurrence(
                originalCycleID: cycle.id,
                nameSnapshot: "Bill \(offset)",
                plannedAmountMinor: Int64(offset * 1_000),
                currencyCode: "USD",
                dueDate: calendar.date(byAdding: .day, value: offset, to: now)!
            )
        }

        let budget = CycleBudgetViewModel(
            snapshot: BudgetSnapshot(
                state: .active,
                leftUntilPaydayMinor: 90_000,
                safeTodayPlanMinor: 7_000,
                safeTodayRemainingMinor: 7_000,
                shortByMinor: 0,
                overTodayPaceMinor: 0
            ),
            spentTodayMinor: 0,
            totalSpentMinor: 0,
            extraIncomeMinor: 0,
            pendingBillsMinor: 10_000,
            pendingBills: bills
        )

        let state = TodayStateBuilder.make(cycle: cycle, budget: budget, now: now, calendar: calendar)

        XCTAssertEqual(state.upcomingBills.count, 3)
        XCTAssertEqual(state.upcomingBills.map(\.name), ["Bill 1", "Bill 2", "Bill 3"])
        XCTAssertEqual(state.upcomingBills.map(\.daysUntilDue), [1, 2, 3])
    }

    func testPaydayTransitionPreservesPreviousCycleLeftover() {
        let today = Calendar.current.startOfDay(for: .now)
        let cycle = PayCycle(startDate: today, endDate: today, incomeMinor: 100_000, currencyCode: "USD")
        let budget = CycleBudgetViewModel(
            snapshot: BudgetSnapshot(
                state: .paydayTransition,
                leftUntilPaydayMinor: 14_200,
                safeTodayPlanMinor: 0,
                safeTodayRemainingMinor: 0,
                shortByMinor: 0,
                overTodayPaceMinor: 0
            ),
            spentTodayMinor: 0,
            totalSpentMinor: 0,
            extraIncomeMinor: 0,
            pendingBillsMinor: 0,
            pendingBills: []
        )

        let state = TodayStateBuilder.make(cycle: cycle, budget: budget, now: today)

        XCTAssertTrue(state.isPaydayReady)
        XCTAssertEqual(state.previousCycleLeftoverMinor, 14_200)
        XCTAssertEqual(state.safeTodayMinor, 0)
    }
}
