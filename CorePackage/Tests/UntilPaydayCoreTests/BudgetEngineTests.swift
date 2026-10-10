import XCTest
@testable import UntilPaydayCore

final class BudgetEngineTests: XCTestCase {
    func testBasicSafeToday() {
        let result = BudgetEngine.calculate(.init(
            baseFundsMinor: 280_000,
            expenseSpentMinor: 0,
            pendingBillReserveMinor: 120_000,
            savingsReserveMinor: 30_000,
            todayFlexibleSpentMinor: 0,
            daysRemaining: 13
        ))
        XCTAssertEqual(result.leftUntilPaydayMinor, 130_000)
        XCTAssertEqual(result.safeTodayPlanMinor, 10_000)
        XCTAssertEqual(result.safeTodayRemainingMinor, 10_000)
    }

    func testVisualMasterScreenshotDatasetIsMathematicallyConsistent() {
        let result = BudgetEngine.calculate(.init(
            baseFundsMinor: 280_000,
            expenseSpentMinor: 94_800,
            pendingBillReserveMinor: 30_000,
            savingsReserveMinor: 30_000,
            todayFlexibleSpentMinor: 4_800,
            daysRemaining: 13
        ))

        XCTAssertEqual(result.leftUntilPaydayMinor, 125_200)
        XCTAssertEqual(result.safeTodayPlanMinor, 10_000)
        XCTAssertEqual(result.safeTodayRemainingMinor, 5_200)
        XCTAssertEqual(result.shortByMinor, 0)
        XCTAssertEqual(result.overTodayPaceMinor, 0)
    }

    func testFortySpentTodayLeavesSixty() {
        let result = BudgetEngine.calculate(.init(
            baseFundsMinor: 280_000,
            expenseSpentMinor: 4_000,
            pendingBillReserveMinor: 120_000,
            savingsReserveMinor: 30_000,
            todayFlexibleSpentMinor: 4_000,
            daysRemaining: 13
        ))
        XCTAssertEqual(result.leftUntilPaydayMinor, 126_000)
        XCTAssertEqual(result.safeTodayPlanMinor, 10_000)
        XCTAssertEqual(result.safeTodayRemainingMinor, 6_000)
    }

    func testOverspendTodayFloorsAtZero() {
        let result = BudgetEngine.calculate(.init(
            baseFundsMinor: 280_000,
            expenseSpentMinor: 12_000,
            pendingBillReserveMinor: 120_000,
            savingsReserveMinor: 30_000,
            todayFlexibleSpentMinor: 12_000,
            daysRemaining: 13
        ))
        XCTAssertEqual(result.safeTodayPlanMinor, 10_000)
        XCTAssertEqual(result.safeTodayRemainingMinor, 0)
        XCTAssertEqual(result.overTodayPaceMinor, 2_000)
    }

    func testNegativeFreeFundsShowsShortBy() {
        let result = BudgetEngine.calculate(.init(
            baseFundsMinor: 10_000,
            expenseSpentMinor: 9_000,
            pendingBillReserveMinor: 5_000,
            savingsReserveMinor: 1_000,
            todayFlexibleSpentMinor: 0,
            daysRemaining: 5
        ))
        XCTAssertEqual(result.leftUntilPaydayMinor, -5_000)
        XCTAssertEqual(result.safeTodayRemainingMinor, 0)
        XCTAssertEqual(result.shortByMinor, 5_000)
    }

    func testPendingBillCanCarryWithoutDoubleReserveWhenGrossCashIsCarried() {
        let old = BudgetEngine.calculate(.init(
            baseFundsMinor: 100_000,
            expenseSpentMinor: 80_000,
            pendingBillReserveMinor: 10_000,
            savingsReserveMinor: 0,
            todayFlexibleSpentMinor: 0,
            daysRemaining: 1
        ))
        XCTAssertEqual(old.leftUntilPaydayMinor, 10_000)

        // Actual unspent cash is free remainder + unpaid reserved bill = 20,000.
        // Carry that gross cash, then reserve the same pending bill once in the new cycle.
        let next = BudgetEngine.calculate(.init(
            baseFundsMinor: 100_000 + old.leftUntilPaydayMinor + 10_000,
            expenseSpentMinor: 0,
            pendingBillReserveMinor: 10_000,
            savingsReserveMinor: 0,
            todayFlexibleSpentMinor: 0,
            daysRemaining: 10
        ))
        XCTAssertEqual(next.leftUntilPaydayMinor, 110_000)
    }

    func testPaydayTransitionAvoidsDivision() {
        let result = BudgetEngine.calculate(.init(
            baseFundsMinor: 100_000,
            expenseSpentMinor: 0,
            pendingBillReserveMinor: 0,
            savingsReserveMinor: 0,
            todayFlexibleSpentMinor: 0,
            daysRemaining: 0
        ))
        XCTAssertEqual(result.state, .paydayTransition)
        XCTAssertEqual(result.leftUntilPaydayMinor, 100_000)
        XCTAssertEqual(result.safeTodayRemainingMinor, 0)
    }

    func testPlannedBillPaymentSameAmountDoesNotChangeFreeFunds() {
        let before = BudgetEngine.calculate(.init(
            baseFundsMinor: 100_000,
            expenseSpentMinor: 0,
            pendingBillReserveMinor: 10_000,
            savingsReserveMinor: 0,
            todayFlexibleSpentMinor: 0,
            daysRemaining: 10
        ))
        let after = BudgetEngine.calculate(.init(
            baseFundsMinor: 100_000,
            expenseSpentMinor: 10_000,
            pendingBillReserveMinor: 0,
            savingsReserveMinor: 0,
            todayFlexibleSpentMinor: 0,
            daysRemaining: 10
        ))
        XCTAssertEqual(before.leftUntilPaydayMinor, after.leftUntilPaydayMinor)
    }

    func testPlannedBillActualTwentyMoreCostsOnlyDifference() {
        let before = BudgetEngine.calculate(.init(
            baseFundsMinor: 100_000,
            expenseSpentMinor: 0,
            pendingBillReserveMinor: 10_000,
            savingsReserveMinor: 0,
            todayFlexibleSpentMinor: 0,
            daysRemaining: 10
        ))
        let after = BudgetEngine.calculate(.init(
            baseFundsMinor: 100_000,
            expenseSpentMinor: 12_000,
            pendingBillReserveMinor: 0,
            savingsReserveMinor: 0,
            todayFlexibleSpentMinor: 0,
            daysRemaining: 10
        ))
        XCTAssertEqual(before.leftUntilPaydayMinor - after.leftUntilPaydayMinor, 2_000)
    }

    func testPlannedBillActualTwentyLessRestoresDifference() {
        let before = BudgetEngine.calculate(.init(
            baseFundsMinor: 100_000,
            expenseSpentMinor: 0,
            pendingBillReserveMinor: 10_000,
            savingsReserveMinor: 0,
            todayFlexibleSpentMinor: 0,
            daysRemaining: 10
        ))
        let after = BudgetEngine.calculate(.init(
            baseFundsMinor: 100_000,
            expenseSpentMinor: 8_000,
            pendingBillReserveMinor: 0,
            savingsReserveMinor: 0,
            todayFlexibleSpentMinor: 0,
            daysRemaining: 10
        ))
        XCTAssertEqual(after.leftUntilPaydayMinor - before.leftUntilPaydayMinor, 2_000)
    }
}

extension BudgetEngineTests {
    func testExtremeNegativeLeftDoesNotOverflowShortBy() {
        let result = BudgetEngine.calculate(.init(
            baseFundsMinor: 0,
            expenseSpentMinor: .max,
            pendingBillReserveMinor: .max,
            savingsReserveMinor: .max,
            todayFlexibleSpentMinor: 0,
            daysRemaining: 5
        ))

        XCTAssertEqual(result.leftUntilPaydayMinor, Int64.min)
        XCTAssertEqual(result.shortByMinor, Int64.max)
        XCTAssertEqual(result.safeTodayRemainingMinor, 0)
    }

    func testStartOfTodayReconstructionSaturatesInsteadOfTrapping() {
        let result = BudgetEngine.calculate(.init(
            baseFundsMinor: .max,
            expenseSpentMinor: 0,
            pendingBillReserveMinor: 0,
            savingsReserveMinor: 0,
            todayFlexibleSpentMinor: .max,
            daysRemaining: 1
        ))

        XCTAssertEqual(result.safeTodayPlanMinor, Int64.max)
        XCTAssertEqual(result.safeTodayRemainingMinor, 0)
    }
}
